import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:skillmatch/models/app_user.dart';
import 'package:skillmatch/models/profile_setup.dart';
import 'package:skillmatch/screens/student/setup/setup_entry_screen.dart';
import 'package:skillmatch/screens/student/setup/setup_wizard_screen.dart';
import 'package:skillmatch/services/auth_service.dart';
import 'package:skillmatch/services/profile_setup_service.dart';
import 'package:skillmatch/widgets/circle_back_button.dart';

class _FakeSetupService extends ProfileSetupService {
  _FakeSetupService({this.error});

  final Object? error;
  final calls = <String>[];

  @override
  Future<void> skip() async {
    calls.add('skip');
    if (error != null) throw error!;
  }

  @override
  Future<void> saveStep1({
    required String name,
    String? address,
    String? zipCode,
    String? phoneNumber,
    String? email,
  }) async {
    calls.add('step1');
  }

  @override
  Future<void> saveStep2({
    String? schoolName,
    String? schoolAddress,
    String? degree,
    String? major,
  }) async {
    calls.add('step2');
  }
}

/// Records pushes so a test can see where Back and Skip lead without mounting
/// the destination — Home builds its own real services.
class _RouteRecorder extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) pushed.add(newRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}

AuthService _session() => AuthService()
  ..currentUser = AppUser(
    id: 1,
    name: 'Zz Probe',
    email: 'zz@skillmatch.test',
    role: 'student',
    status: 'active',
  );

Future<void> _pumpWizard(
  WidgetTester tester,
  ProfileSetupService service, {
  _RouteRecorder? observer,
}) async {
  // Skip lands on Home, which reads the session from the provider — so the
  // harness has to carry one even though these tests never look at Home.
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthService>.value(
      value: _session(),
      child: MaterialApp(
        navigatorObservers: [?observer],
        home: SetupWizardScreen(service: service, parsed: ParsedResume.empty()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpEntry(
  WidgetTester tester,
  ProfileSetupService service,
) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthService>.value(
      value: _session(),
      child: MaterialApp(home: SetupEntryScreen(service: service)),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _lastDestination(WidgetTester tester, _RouteRecorder observer) {
  final route = observer.pushed.last as MaterialPageRoute;
  return route.builder(tester.element(find.byType(MaterialApp)));
}

void main() {
  group('skip', () {
    testWidgets('is offered on the very first setup screen', (tester) async {
      await _pumpEntry(tester, _FakeSetupService());

      expect(find.text('Skip for now'), findsOneWidget);
    });

    testWidgets('is offered on every step of the wizard, not just the first', (
      tester,
    ) async {
      final service = _FakeSetupService();
      await _pumpWizard(tester, service);

      expect(find.text('Skip for now'), findsOneWidget);
      expect(find.text('Step 1'), findsOneWidget);

      // On to step 2 — the button has to still be there.
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Step 2'), findsOneWidget);
      expect(find.text('Skip for now'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Step 3'), findsOneWidget);
      expect(find.text('Skip for now'), findsOneWidget);
    });

    testWidgets('tells the server setup was skipped', (tester) async {
      final service = _FakeSetupService();
      final observer = _RouteRecorder();
      await _pumpWizard(tester, service, observer: observer);

      await tester.tap(find.text('Skip for now'));
      await tester.pump();

      expect(service.calls, contains('skip'));
    });

    testWidgets('says so when skipping fails, and stays put', (tester) async {
      final service = _FakeSetupService(error: Exception('offline'));
      await _pumpWizard(tester, service);

      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Something went wrong'), findsOneWidget);
      expect(find.text('Step 1'), findsOneWidget);
    });
  });

  group('leaving the entry screen', () {
    testWidgets('there is a back button on the upload/fill-in screen', (
      tester,
    ) async {
      await _pumpEntry(tester, _FakeSetupService());

      expect(find.byType(CircleBackButton), findsOneWidget);
    });

    testWidgets('it asks before signing out, and staying changes nothing', (
      tester,
    ) async {
      final session = _session();
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthService>.value(
          value: session,
          child: MaterialApp(
            home: SetupEntryScreen(service: _FakeSetupService()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CircleBackButton));
      await tester.pumpAndSettle();

      expect(find.text('Leave setup?'), findsOneWidget);

      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle();

      expect(session.currentUser, isNotNull, reason: 'still signed in');
      expect(find.byType(SetupEntryScreen), findsOneWidget);
    });
  });

  group('back', () {
    testWidgets('steps backwards through the wizard', (tester) async {
      await _pumpWizard(tester, _FakeSetupService());

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Step 2'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Back'));
      await tester.pumpAndSettle();

      expect(find.text('Step 1'), findsOneWidget);
    });

    testWidgets('on step 1 it returns to the entry screen', (tester) async {
      // The entry screen reached the wizard with pushReplacement, so there is
      // nothing on the stack to pop — Back used to do nothing at all here.
      final observer = _RouteRecorder();
      await _pumpWizard(tester, _FakeSetupService(), observer: observer);

      expect(find.text('Step 1'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Back'));
      await tester.pump();

      expect(_lastDestination(tester, observer), isA<SetupEntryScreen>());
    });

    testWidgets('the system back gesture does the same as the button', (
      tester,
    ) async {
      await _pumpWizard(tester, _FakeSetupService());

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Step 2'), findsOneWidget);

      // What Android's back gesture triggers.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(
        find.text('Step 1'),
        findsOneWidget,
        reason: 'back should step the wizard, not leave it',
      );
    });
  });
}
