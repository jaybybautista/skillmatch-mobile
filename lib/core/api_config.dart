import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

///irun mo ito:
///   php artisan serve --host=0.0.0.0 --port=8000 --no-reload
/// para mafetch niya

class ApiConfig {
  ApiConfig._();

  /// Saan nakaturo ang app.
  ///
  /// Isa lang dapat ang bukas dito. Kapag wala o kapag dalawa, hindi tatakbo.
  ///
  /// Hindi mo na rin kailangang galawin ito. Isabay mo na lang sa pagpapatakbo
  /// kung saan ka naka-kabit ngayon:
  ///   flutter run --dart-define=SKILLMATCH_HOST=192.168.100.51
  ///
  /// Nauuna ang dart-define kaysa sa nakasulat dito.

  // Radmin VPN. Ito ang inaabot ng grupo kahit magkakaiba ang wifi nila. Sa
  // emulator lang ito gumagana - walang Radmin sa Android, kaya hindi kayang
  // sumali dito ang totoong cellphone.
  // static const String _defaultHost = '26.29.85.220';

  ///same dapat ung ip teh ng wifi niyu, check mo nalang ipconfig tas same wifi dapat
  //wifi sa bahay
  static const String _defaultHost = '192.168.100.51';
  // defense wifi
  // static const String _defaultHost = '132.168.7.163';
  //wifi ng ssc
  // static const String _defaultHost = '192.168.101.184';

  static const String _lanHost = String.fromEnvironment(
    'SKILLMATCH_HOST',
    defaultValue: _defaultHost,
  );

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

  /// Buong address, para sa tunnel gaya ng Cloudflare o ngrok.
  ///
  /// Dito lang dumadaan ang totoong cellphone kapag magkaiba kayo ng wifi.
  /// Ang Radmin kasi, Windows lang - walang app sa Android o iOS.
  ///
  /// Patakbuhin mo muna ang tunnel, tapos yung address na ibibigay niya ang
  /// ilalagay mo dito. Hindi ito pangalan na basta susulatin:
  ///   cloudflared tunnel --url http://localhost/SkillMatch/SkillMatch/public
  ///   flutter run --dart-define=SKILLMATCH_ORIGIN=yung_address_na_lumabas
  ///
  /// Kasama na dito ang https at ang landas, kaya hindi na ito dumadaan sa
  /// _lanHost at sa _apachePath. Nauuna rin ito sa SKILLMATCH_HOST.
  static const String _originOverride = String.fromEnvironment('SKILLMATCH_ORIGIN');

  /// Apache listens on port 80 and serves the project from a sub-path;
  /// artisan serve owns its port and serves from the root.
  static String get _origin {
    if (_originOverride.isNotEmpty) {
      // Tinatanggal yung tirang tulis sa dulo, kung meron man, para hindi
      // dumoble kapag idinugtong na ang /api.
      return _originOverride.replaceAll(RegExp(r'/+$'), '');
    }

    return _useApache ? 'http://$_host$_apachePath' : 'http://$_host:$port';
  }

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
