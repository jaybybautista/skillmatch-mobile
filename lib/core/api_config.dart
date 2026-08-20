import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

///irun mo ito:
///   php artisan serve --host=0.0.0.0 --port=8000
/// para mafetch niya

class ApiConfig {
  ApiConfig._();

  ///same dapat ung ip teh ng wifi niyu, check mo nalang ipconfig tas same wifi dapat
  static const String _lanHost = '192.168.100.51';

  ///gawin mo siyang true teh if want mo gumamit ng emulator
  static const bool _useAndroidEmulator = false;

  /// Serve through XAMPP's Apache rather than `php artisan serve`.
  ///
  /// On Windows the artisan dev server is always single-threaded — PHP needs
  /// fork() for its workers and Windows has none, so `--no-reload` just prints
  /// "forking is not supported on this platform". One slow request (the AI
  /// matching service timing out, say) therefore blocks every other request,
  /// and the app starts timing out on unrelated screens. Apache is
  /// multi-process and doesn't have that problem.
  ///
  /// Set this to false to go back to `php artisan serve --host=0.0.0.0`.
  static const bool _useApache = true;

  /// Where XAMPP serves the project from, relative to the web root.
  static const String _apachePath = '/SkillMatch/SkillMatch/public';

  static const int port = 8000;

  static String get _host {
    if (kIsWeb) return 'localhost';
    if (Platform.isAndroid) return _useAndroidEmulator ? '10.0.2.2' : _lanHost;
    // iOS physical devices need the LAN IP too.
    if (Platform.isIOS) {
      return _lanHost;
    }
    return 'localhost';
  }

  /// Apache listens on port 80 and serves the project from a sub-path;
  /// artisan serve owns its port and serves from the root.
  static String get _origin =>
      _useApache ? 'http://$_host$_apachePath' : 'http://$_host:$port';

  static String get baseUrl => '$_origin/api';

  /// The SkillMatch website itself (not the API). Shown to anyone the app has
  /// to turn away — company sign-ups and coordinator/admin sign-ins both live
  /// on the web, since the app only has student screens.
  static String get siteUrl => _origin;

  /// The same "Web application" OAuth client ID the Laravel backend already
  /// uses for Socialite (GOOGLE_CLIENT_ID in the web .env). Passing this as
  /// google_sign_in's `serverClientId` makes the ID token it returns carry
  /// this client ID as its audience, which is exactly what the backend
  /// checks in Api\AuthController::googleLogin(). This value is a public
  /// client identifier, not a secret, so it's safe to embed in the app.
  static const String googleServerClientId =
      '1066842512355-4b43vtle1psfm58vk50757916447ng7r.apps.googleusercontent.com';
}
