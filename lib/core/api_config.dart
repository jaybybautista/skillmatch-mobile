import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Central place to point the app at the SkillMatch Laravel backend.
///
/// The web project is served via `php artisan serve` on port 8000 (see
/// APP_URL in the Laravel .env). Run it reachable from other devices on your
/// network with:
///
///   php artisan serve --host=0.0.0.0 --port=8000
///
/// Then pick the right host below depending on how you're running the app:
///
/// - Physical phone (USB or wireless debugging): use your PC's LAN IP —
///   both devices must be on the same Wi-Fi network. Find it with
///   `ipconfig` (look for "IPv4 Address" under your Wi-Fi adapter).
/// - Android emulator: use the special alias 10.0.2.2, which the emulator
///   maps back to your host machine's localhost.
/// - iOS simulator / web / desktop: use localhost directly.
class ApiConfig {
  ApiConfig._();

  /// Your computer's LAN IP — used when testing on a physical device.
  /// Update this if your PC's IP changes (e.g. you reconnect to Wi-Fi).
  static const String _lanHost = '192.168.100.51';

  /// Flip to true only when running on the Android *emulator* (not a real
  /// phone) — swaps in the 10.0.2.2 loopback alias instead of [_lanHost].
  static const bool _useAndroidEmulator = false;

  static const int port = 8000;

  static String get _host {
    if (kIsWeb) return 'localhost';
    if (Platform.isAndroid) return _useAndroidEmulator ? '10.0.2.2' : _lanHost;
    if (Platform.isIOS) return _lanHost; // iOS physical devices need the LAN IP too.
    return 'localhost';
  }

  static String get baseUrl => 'http://$_host:$port/api';

  /// The same "Web application" OAuth client ID the Laravel backend already
  /// uses for Socialite (GOOGLE_CLIENT_ID in the web .env). Passing this as
  /// google_sign_in's `serverClientId` makes the ID token it returns carry
  /// this client ID as its audience, which is exactly what the backend
  /// checks in Api\AuthController::googleLogin(). This value is a public
  /// client identifier, not a secret, so it's safe to embed in the app.
  static const String googleServerClientId =
      '1066842512355-4b43vtle1psfm58vk50757916447ng7r.apps.googleusercontent.com';
}
