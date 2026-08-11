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
class AuthService extends ChangeNotifier {
  final ApiClient _client = ApiClient.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  Future<void>? _googleInitFuture;

  AppUser? currentUser;
  bool isCheckingSession = true;

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
    return (response['campuses'] as List).map((e) => Campus.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AppUser> login({required String email, required String password}) async {
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
      _googleInitFuture ??= _googleSignIn.initialize(serverClientId: ApiConfig.googleServerClientId);
      await _googleInitFuture;
    } catch (e) {
      debugPrint('[Google] initialize() failed: $e');
      _googleInitFuture = null; // Let the next attempt retry initialization.
      throw ApiException('Google sign-in is not set up correctly yet. Please try again shortly.');
    }

    final GoogleSignInAccount account;
    try {
      account = await _googleSignIn.authenticate();
      debugPrint('[Google] authenticate() succeeded for ${account.email}');
    } on GoogleSignInException catch (e) {
      debugPrint('[Google] authenticate() threw GoogleSignInException code=${e.code} description=${e.description}');

      // The Android plugin sometimes reports real configuration failures
      // (e.g. "Account reauth failed" when the app's OAuth client isn't
      // registered / isn't a test user on the consent screen) under the
      // same `canceled` code as a genuine user dismissal. Only treat it as
      // a silent cancel when there's no description — a real description
      // means something actually went wrong and should be shown.
      final isGenuineCancel = e.code == GoogleSignInExceptionCode.canceled && (e.description?.isEmpty ?? true);
      if (isGenuineCancel) return null;

      throw ApiException('Google sign-in failed: ${e.description ?? e.code.name}');
    }

    final idToken = account.authentication.idToken;
    debugPrint('[Google] idToken present: ${idToken != null}');
    if (idToken == null) {
      throw ApiException(
        'Google did not return a valid sign-in token. This usually means the Android OAuth client '
        'isn\'t registered yet in Google Cloud Console. Please try again.',
      );
    }

    debugPrint('[Google] posting id_token to /auth/google at ${ApiConfig.baseUrl}');
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

  Future<AppUser> _persistSession(Map<String, dynamic> response) async {
    final token = response['token'] as String;
    await TokenStorage.instance.saveToken(token);

    final user = AppUser.fromJson(response['user'] as Map<String, dynamic>);
    currentUser = user;
    notifyListeners();
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
    final response = await _client.post('/auth/forgot-password', {'email': email});
    return response['message'] as String;
  }

  Future<void> verifyPasswordResetCode({required String email, required String code}) async {
    await _client.post('/auth/forgot-password/verify', {'email': email, 'code': code});
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
