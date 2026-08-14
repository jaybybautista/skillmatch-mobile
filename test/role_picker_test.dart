import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:skillmatch/screens/auth/auth_screen.dart';
import 'package:skillmatch/screens/auth/register_screen.dart';
import 'package:skillmatch/screens/auth/role_picker_screen.dart';
import 'package:skillmatch/services/auth_service.dart';

Widget _wrap(Widget child) => ChangeNotifierProvider(
      create: (_) => AuthService(),
      child: MaterialApp(home: child),
    );

void main() {
  testWidgets('Sign Up on the login screen opens the role picker', (tester) async {
    await tester.pumpWidget(_wrap(const AuthScreen()));
    await tester.pump();

    expect(find.byType(RolePickerScreen), findsNothing);

    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();

    expect(find.byType(RolePickerScreen), findsOneWidget);
    expect(find.text('Describe Your Role'), findsOneWidget);
    expect(find.text('Student'), findsOneWidget);
    expect(find.text('Company'), findsOneWidget);
  });

  testWidgets('the picker is shown again on every trip to registration', (tester) async {
    await tester.pumpWidget(_wrap(const AuthScreen()));
    await tester.pump();

    for (var visit = 0; visit < 2; visit++) {
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();
      expect(find.text('Describe Your Role'), findsOneWidget, reason: 'visit $visit');

      // The picker has no app bar (it matches the full-bleed mockup), so back
      // out through the navigator the way the Android back gesture would.
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(find.byType(RolePickerScreen), findsNothing, reason: 'visit $visit');
    }
  });

  testWidgets('Student continues into the sign-up form', (tester) async {
    await tester.pumpWidget(_wrap(const RolePickerScreen()));
    await tester.pump();

    await tester.tap(find.text('Student'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.text('Signing up as a Student'), findsOneWidget);
  });

  testWidgets('Company explains that sign-up happens on the website', (tester) async {
    await tester.pumpWidget(_wrap(const RolePickerScreen()));
    await tester.pump();

    await tester.tap(find.text('Company'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(RegisterScreen), findsNothing);
    expect(
      find.textContaining('created on the website'),
      findsOneWidget,
    );
  });

  testWidgets('Student is preselected and selection follows the tap', (tester) async {
    await tester.pumpWidget(_wrap(const RolePickerScreen()));
    await tester.pump();

    // Several widgets between the label and the screen wrap it in Semantics
    // (Material, InkWell); only the card sets `selected`, so pick that one.
    bool isSelected(String label) {
      final matches = tester
          .widgetList<Semantics>(find.ancestor(of: find.text(label), matching: find.byType(Semantics)))
          .where((s) => s.properties.selected != null)
          .toList();

      expect(matches, hasLength(1), reason: 'exactly one card should own the selected state for $label');
      return matches.single.properties.selected!;
    }

    expect(isSelected('Student'), isTrue);
    expect(isSelected('Company'), isFalse);

    await tester.tap(find.text('Company'));
    await tester.pump();

    expect(isSelected('Student'), isFalse);
    expect(isSelected('Company'), isTrue);
  });
}
