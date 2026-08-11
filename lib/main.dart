import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/app_routing.dart';
import 'core/app_theme.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/setup/setup_entry_screen.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';
import 'services/profile_setup_service.dart';

void main() {
  runApp(const SkillMatchApp());
}

class SkillMatchApp extends StatelessWidget {
  const SkillMatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthService()..restoreSession(),
      child: MaterialApp(
        title: 'SkillMatch',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        navigatorObservers: [routeObserver],
        home: const _SessionGate(),
      ),
    );
  }
}

/// Decides where a launch lands: the login screen, the first-run profile
/// wizard, or Home.
///
/// The branded splash covers both waits — restoring the saved token and asking
/// the server whether setup is still needed — so the app never flashes through
/// an intermediate screen.
class _SessionGate extends StatefulWidget {
  const _SessionGate();

  @override
  State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate> {
  final _setupService = ProfileSetupService();

  /// Null until we know; set once the setup state has been resolved for the
  /// current session.
  bool? _needsSetup;

  /// Which login the [_needsSetup] answer belongs to, so logging out and back
  /// in as someone else re-checks rather than reusing the previous answer.
  bool _resolvedForLoggedIn = false;
  bool _isResolving = false;

  Future<void> _resolveSetupState() async {
    if (_isResolving) return;
    _isResolving = true;

    // The splash should be seen, not flashed — hold it for a beat even when
    // the request returns immediately.
    final started = DateTime.now();
    bool needsSetup = false;

    try {
      needsSetup = (await _setupService.fetchState()).needsSetup;
    } on ApiException {
      // Offline or an unexpected failure shouldn't strand a returning student
      // on the splash; send them to Home and let the screens report problems.
      needsSetup = false;
    } catch (_) {
      needsSetup = false;
    }

    final elapsed = DateTime.now().difference(started);
    if (elapsed < SplashScreen.minimumDuration) {
      await Future<void>.delayed(SplashScreen.minimumDuration - elapsed);
    }

    if (!mounted) return;
    setState(() {
      _needsSetup = needsSetup;
      _resolvedForLoggedIn = true;
      _isResolving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (auth.isCheckingSession) {
      return const SplashScreen();
    }

    if (!auth.isLoggedIn) {
      // Logging out invalidates any earlier answer.
      if (_resolvedForLoggedIn) {
        _needsSetup = null;
        _resolvedForLoggedIn = false;
      }
      return const AuthScreen();
    }

    if (_needsSetup == null) {
      // Kick the check off after this frame so it doesn't setState mid-build.
      WidgetsBinding.instance.addPostFrameCallback((_) => _resolveSetupState());
      return const SplashScreen();
    }

    return _needsSetup! ? const SetupEntryScreen() : const HomeScreen();
  }
}
