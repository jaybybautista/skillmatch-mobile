import 'package:flutter_test/flutter_test.dart';

import 'package:skillmatch/main.dart';
import 'package:skillmatch/models/app_user.dart';
import 'package:skillmatch/models/profile_setup.dart';
import 'package:skillmatch/screens/auth/auth_screen.dart';
import 'package:skillmatch/screens/company/company_home_screen.dart';
import 'package:skillmatch/screens/splash_screen.dart';
import 'package:skillmatch/screens/student/home/home_screen.dart';
import 'package:skillmatch/screens/student/setup/setup_entry_screen.dart';
import 'package:skillmatch/services/auth_service.dart';
import 'package:skillmatch/services/profile_setup_service.dart';

/// An AuthService with no network behind it: the tests drive the session by
/// hand, exactly as a real sign-in would once it has persisted.
class _FakeAuthService extends AuthService {
  _FakeAuthService({AppUser? user, bool checking = false}) {
    currentUser = user;
    isCheckingSession = checking;
  }

  /// What a successful login does to this object: sets the user, then tells
  /// everyone listening. If the launch gate doesn't move after this, nothing
  /// in the app will.
  void completeSignIn(AppUser user) {
    currentUser = user;
    isCheckingSession = false;
    notifyListeners();
  }

  void completeSignOut() {
    currentUser = null;
    notifyListeners();
  }

  @override
  Future<void> restoreSession() async {}
}

class _FakeSetupService extends ProfileSetupService {
  _FakeSetupService({this.needsSetup = false, this.error});

  bool needsSetup;
  Object? error;
  int calls = 0;

  @override
  Future<SetupState> fetchState() async {
    calls++;
    if (error != null) throw error!;
    return SetupState.fromJson({
      'needs_setup': needsSetup,
      'setup_complete': !needsSetup,
      'setup_skipped': false,
      'prefill': const <String, dynamic>{},
    });
  }
}

AppUser _user({String role = 'student', int? companyId}) => AppUser(
  id: 1,
  name: role == 'company' ? 'SkillMatch' : 'Zz Probe',
  email: 'someone@skillmatch.test',
  role: role,
  status: 'active',
  companyId: companyId,
);

Future<void> _pump(
  WidgetTester tester,
  _FakeAuthService auth,
  _FakeSetupService setup,
) async {
  await tester.pumpWidget(SkillMatchApp(auth: auth, setupService: setup));
  await tester.pump();
}

/// The gate holds the splash for a beat on purpose, so the routing decision
/// lands a little after the session changes.
///
/// Bounded pumps rather than pumpAndSettle: Home builds its own real services
/// and spins a loading indicator that never stops in a test, so settling would
/// wait forever on an animation that has nothing to do with the routing.
Future<void> _settleGate(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(SplashScreen.minimumDuration);
  }
}

void main() {
  testWidgets('a signed-out launch shows the login screen', (tester) async {
    await _pump(tester, _FakeAuthService(), _FakeSetupService());

    expect(find.byType(AuthScreen), findsOneWidget);
  });

  testWidgets('signing in as a student with setup done lands on Home', (
    tester,
  ) async {
    final auth = _FakeAuthService();
    final setup = _FakeSetupService(needsSetup: false);
    await _pump(tester, auth, setup);

    expect(find.byType(AuthScreen), findsOneWidget);

    auth.completeSignIn(_user());
    await _settleGate(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(setup.calls, 1);
  });

  testWidgets('a brand-new student lands on the setup wizard', (tester) async {
    final auth = _FakeAuthService();
    final setup = _FakeSetupService(needsSetup: true);
    await _pump(tester, auth, setup);

    auth.completeSignIn(_user());
    await _settleGate(tester);

    expect(find.byType(SetupEntryScreen), findsOneWidget);
  });

  testWidgets('a company skips the student setup check entirely', (
    tester,
  ) async {
    final auth = _FakeAuthService();
    final setup = _FakeSetupService();
    await _pump(tester, auth, setup);

    auth.completeSignIn(_user(role: 'company', companyId: 1));
    await tester.pump();

    expect(find.byType(CompanyHomeScreen), findsOneWidget);
    expect(
      setup.calls,
      0,
      reason: 'the setup endpoint is student-only and would fail',
    );
  });

  testWidgets('a failed setup check still lets the student in', (tester) async {
    final auth = _FakeAuthService();
    final setup = _FakeSetupService(error: Exception('offline'));
    await _pump(tester, auth, setup);

    auth.completeSignIn(_user());
    await _settleGate(tester);

    // Being offline must not strand anyone on the splash.
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('the gate survives navigation, so a second login still routes', (
    tester,
  ) async {
    // The bug this guards: logging out used to clear the whole route stack,
    // and the gate is the first route. Once it was gone, the next login
    // published a session that nothing was listening for — the app simply sat
    // on the login screen, for Google and email alike.
    final auth = _FakeAuthService();
    final setup = _FakeSetupService(needsSetup: false);
    await _pump(tester, auth, setup);

    auth.completeSignIn(_user());
    await _settleGate(tester);
    expect(find.byType(HomeScreen), findsOneWidget);

    // Wherever the app has wandered to, the gate must still be underneath.
    auth.completeSignOut();
    await tester.pump();
    expect(find.byType(AuthScreen), findsOneWidget);

    setup.needsSetup = false;
    auth.completeSignIn(_user());
    await _settleGate(tester);

    expect(
      find.byType(HomeScreen),
      findsOneWidget,
      reason: 'the second login has to route just like the first',
    );

    // And a third time, because the report was that it degraded with each
    // logout rather than failing outright.
    auth.completeSignOut();
    await tester.pump();
    auth.completeSignIn(_user());
    await _settleGate(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('finishing setup sends the student on without re-asking', (
    tester,
  ) async {
    final auth = _FakeAuthService();
    final setup = _FakeSetupService(needsSetup: true);
    await _pump(tester, auth, setup);

    auth.completeSignIn(_user());
    await _settleGate(tester);
    expect(find.byType(SetupEntryScreen), findsOneWidget);

    // What the wizard does when it finishes or is skipped.
    setup.needsSetup = false;
    auth.invalidateSetupState();
    await _settleGate(tester);

    expect(
      find.byType(HomeScreen),
      findsOneWidget,
      reason: 'the cached "needs setup" answer must not survive finishing it',
    );
  });

  testWidgets('signing out returns to login, and back in re-checks setup', (
    tester,
  ) async {
    final auth = _FakeAuthService();
    final setup = _FakeSetupService(needsSetup: false);
    await _pump(tester, auth, setup);

    auth.completeSignIn(_user());
    await _settleGate(tester);
    expect(find.byType(HomeScreen), findsOneWidget);

    auth.completeSignOut();
    await tester.pump();
    expect(find.byType(AuthScreen), findsOneWidget);

    // A different account may be at a different stage, so the answer from the
    // previous session must not be reused.
    setup.needsSetup = true;
    auth.completeSignIn(_user());
    await _settleGate(tester);

    expect(find.byType(SetupEntryScreen), findsOneWidget);
    expect(setup.calls, 2, reason: 'the check has to run again');
  });
}
