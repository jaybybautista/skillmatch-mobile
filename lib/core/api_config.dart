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

  static const int port = 8000;

  static String get _host {
    if (kIsWeb) return 'localhost';
    if (Platform.isAndroid) return _useAndroidEmulator ? '10.0.2.2' : _lanHost;
    if (Platform.isIOS) return _lanHost; // iOS physical devices need the LAN IP too.
    return 'localhost';
  }

  static String get baseUrl => 'http://$_host:$port/api';

  /// The SkillMatch website itself (not the API). Shown to anyone the app has
  /// to turn away — company sign-ups and coordinator/admin sign-ins both live
  /// on the web, since the app only has student screens.
  static String get siteUrl => 'http://$_host:$port';

  /// The same "Web application" OAuth client ID the Laravel backend already
  /// uses for Socialite (GOOGLE_CLIENT_ID in the web .env). Passing this as
  /// google_sign_in's `serverClientId` makes the ID token it returns carry
  /// this client ID as its audience, which is exactly what the backend
  /// checks in Api\AuthController::googleLogin(). This value is a public
  /// client identifier, not a secret, so it's safe to embed in the app.
  static const String googleServerClientId =
      '1066842512355-4b43vtle1psfm58vk50757916447ng7r.apps.googleusercontent.com';
}
