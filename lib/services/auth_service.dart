import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/api_client.dart';
import '../core/api_config.dart';
import '../core/token_storage.dart';
import '../models/app_user.dart';
import '../models/campus.dart';

/// Holds the current session and talks to the Laravel Sanctum API.
///
/// This mirrors the web app's `AuthController` (routes/api.php ->
/// App\Http\Controllers\Api\AuthController) so anything that happens here —
/// registering, logging in, resetting a password — updates the exact same
/// `users`/`students` tables the web app reads from.
/// Panakip lang pag hindi maabot ang server. Sa App\Support\Industries ang
/// tunay na listahan - dito lang ito nakasulat para may mapipili pa rin sila
/// kahit mahina ang signal habang nagpaparehistro.
const List<String> kFallbackIndustries = [
  'Information Technology',
  'Software Development',
  'Business Process Outsourcing',
  'Banking & Finance',
  'Insurance',
  'Healthcare',
  'Education',
  'Engineering',
  'Construction',
  'Manufacturing',
  'Retail & E-commerce',
  'Food & Beverage',
  'Hospitality & Tourism',
  'Transportation & Logistics',
  'Agriculture',
  'Real Estate',
  'Media & Communications',
  'Government',
  'Non-profit / NGO',
];

/// How long the account picker has to be up before a "cancel" is believable
/// as a human dismissal. Anything faster never showed a picker at all.
const _pickerDismissFloor = Duration(milliseconds: 1200);

/// Facts about this build that error messages need to name.
class AppIdentity {
  AppIdentity._();

  /// Must match `applicationId` in android/app/build.gradle.kts — it is half
  /// of what identifies the app to Google (the signing certificate is the
  /// other half).
  static const String androidPackage = 'edu.psu.skillmatch';
}

class AuthService extends ChangeNotifier {
  final ApiClient _client = ApiClient.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  Future<void>? _googleInitFuture;

  AppUser? currentUser;
  bool isCheckingSession = true;

  /// Bumped whenever something changes whether the profile-setup wizard is
  /// still needed, so the launch gate re-asks the server instead of reusing
  /// the answer it cached when the session started.
  int setupRevision = 0;

  void invalidateSetupState() {
    setupRevision++;
    notifyListeners();
  }

  bool get isLoggedIn => currentUser != null;

  /// Called once on app startup: if a token was persisted from a previous
  /// session, validate it against the API and restore the user.
  Future<void> restoreSession() async {
    String? token;
    try {
      token = await TokenStorage.instance.readToken();
    } catch (_) {
      token = null;
    }

    if (token == null) {
      isCheckingSession = false;
      notifyListeners();
      return;
    }

    try {
      final response = await _client.get('/auth/me', authenticated: true);
      currentUser = AppUser.fromJson(response['user'] as Map<String, dynamic>);
    } catch (_) {
      try {
        await TokenStorage.instance.clear();
      } catch (_) {
        // Ignore — secure storage may be unavailable (e.g. in tests).
      }
      currentUser = null;
    }

    isCheckingSession = false;
    notifyListeners();
  }

  Future<List<Campus>> fetchCampuses() async {
    final response = await _client.get('/auth/campuses');
    return (response['campuses'] as List)
        .map((e) => Campus.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Yung mapipiling larangan ng kompanya.
  ///
  /// Sa server nakuha para iisa lang ang listahan ng web at ng app. Tatlong
  /// magkakaibang kopya kasi ito dati - isa sa pagpaparehistro sa web, isa sa
  /// profile sa web, isa dito - at hindi sila magkatugma. Kaya pag may pinili
  /// sila sa isa, hindi ito nakikita ng isa, tas nabubura pagka-save.
  ///
  /// Pag hindi maabot ang server, [kFallbackIndustries] naman ang gamit, para
  /// may mapipili pa rin sila.
  Future<List<String>> fetchIndustries() async {
    try {
      final response = await _client.get('/auth/industries');
      final industries = (response['industries'] as List? ?? const [])
          .map((e) => e.toString())
          .toList();

      return industries.isEmpty ? kFallbackIndustries : industries;
    } catch (_) {
      return kFallbackIndustries;
    }
  }

  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post('/auth/login', {
      'email': email,
      'password': password,
    });

    return _persistSession(response);
  }

  Future<AppUser> register({
    required String firstName,
    required String lastName,
    required String course,
    required int campusId,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final response = await _client.post('/auth/register', {
      'first_name': firstName,
      'last_name': lastName,
      'course': course,
      'campus_id': campusId,
      'email': email,
      'password': password,
      'password_confirmation': passwordConfirmation,
    });

    return _persistSession(response);
  }

  /// Signs in with a native Google account picker, then exchanges the
  /// resulting ID token for a SkillMatch session via
  /// Api\AuthController::googleLogin on the backend.
  ///
  /// Returns null if the user dismissed the account picker (not an error).
  /// Throws [ApiException] for any real failure.
  Future<AppUser?> loginWithGoogle() async {
    try {
      _googleInitFuture ??= _googleSignIn.initialize(
        serverClientId: ApiConfig.googleServerClientId,
      );
      await _googleInitFuture;
    } catch (e) {
      debugPrint('[Google] initialize() failed: $e');
      _googleInitFuture = null; // Let the next attempt retry initialization.
      throw ApiException(
        'Google sign-in is not set up correctly yet. Please try again shortly.',
      );
    }

    // Timed, because the Android plugin reports a configuration failure and a
    // real dismissal under the same `canceled` code (see below).
    final startedAt = DateTime.now();

    final GoogleSignInAccount account;
    try {
      account = await _googleSignIn.authenticate();
      debugPrint('[Google] authenticate() succeeded for ${account.email}');
    } on GoogleSignInException catch (e) {
      debugPrint(
        '[Google] authenticate() threw GoogleSignInException code=${e.code} description=${e.description}',
      );

      // The Android plugin sometimes reports real configuration failures
      // (e.g. the app's OAuth client isn't registered, or the account isn't a
      // test user on the consent screen) under the same `canceled` code as a
      // genuine user dismissal, with no description either way.
      //
      // What separates them is how fast it comes back: nobody sees an account
      // picker and dismisses it inside a second, so a "cancel" that quick is
      // the picker never having appeared at all. Reporting that as a silent
      // cancel is what makes tapping the button look like it does nothing.
      final looksCancelled =
          e.code == GoogleSignInExceptionCode.canceled &&
          (e.description?.isEmpty ?? true);

      if (looksCancelled) {
        final elapsed = DateTime.now().difference(startedAt);
        if (elapsed >= _pickerDismissFloor) return null;

        throw ApiException(
          'Google sign-in closed immediately, which usually means this app '
          'build is not registered for Google sign-in yet: an Android OAuth '
          'client for package ${AppIdentity.androidPackage} with this '
          "machine's debug signing certificate has to exist in Google Cloud "
          'Console, and the account has to be a test user on the consent '
          'screen. Signing in with an email and password works either way.',
        );
      }

      throw ApiException(
        'Google sign-in failed: ${e.description ?? e.code.name}',
      );
    }

    final idToken = account.authentication.idToken;
    debugPrint('[Google] idToken present: ${idToken != null}');
    if (idToken == null) {
      throw ApiException(
        'Google did not return a valid sign-in token. This usually means the Android OAuth client '
        'isn\'t registered yet in Google Cloud Console. Please try again.',
      );
    }

    debugPrint(
      '[Google] posting id_token to /auth/google at ${ApiConfig.baseUrl}',
    );
    final Map<String, dynamic> response;
    try {
      response = await _client.post('/auth/google', {'id_token': idToken});
    } catch (e) {
      debugPrint('[Google] backend call to /auth/google failed: $e');
      rethrow;
    }
    debugPrint('[Google] backend call succeeded, persisting session');

    return _persistSession(response);
  }

  /// Turns a successful auth response into a live session.
  ///
  /// By the time this runs the server has already accepted the credentials, so
  /// nothing in here is allowed to throw away that success. Every step is
  /// either guaranteed not to throw or is reported precisely — a login that
  /// worked must never come back as "sign-in failed", which is what happened
  /// when a device keystore refused the write.
  Future<AppUser> _persistSession(Map<String, dynamic> response) async {
    final token = response['token'];
    if (token is! String || token.isEmpty) {
      debugPrint('[Session] the server returned no token: ${response.keys}');
      throw ApiException(
        'Signed in, but the server did not return a session token. '
        'Please try again.',
      );
    }

    final AppUser user;
    try {
      user = AppUser.fromJson(response['user'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[Session] could not read the account from the response: $e');
      throw ApiException(
        'Signed in, but the account details could not be read. '
        'Please try again.',
      );
    }

    // Never awaited on the keystore: saveToken records the token in memory
    // and persists in the background, so a store that refuses or hangs costs
    // the next launch's auto-login, not this one.
    await TokenStorage.instance.saveToken(token);

    currentUser = user;
    notifyListeners();
    debugPrint('[Session] signed in as ${user.email} (${user.role})');
    return user;
  }

  Future<void> logout() async {
    try {
      await _client.post('/auth/logout', {}, authenticated: true);
    } catch (_) {
      // Token may already be invalid server-side — clear locally regardless.
    }
    if (_googleInitFuture != null) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {
        // Best-effort — a stale Google session isn't worth failing logout over.
      }
    }
    await TokenStorage.instance.clear();
    currentUser = null;
    notifyListeners();
  }

  Future<String> sendPasswordResetCode(String email) async {
    final response = await _client.post('/auth/forgot-password', {
      'email': email,
    });
    return response['message'] as String;
  }

  Future<void> verifyPasswordResetCode({
    required String email,
    required String code,
  }) async {
    await _client.post('/auth/forgot-password/verify', {
      'email': email,
      'code': code,
    });
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String password,
    required String passwordConfirmation,
  }) async {
    await _client.post('/auth/forgot-password/reset', {
      'email': email,
      'code': code,
      'password': password,
      'password_confirmation': passwordConfirmation,
    });
  }
}
