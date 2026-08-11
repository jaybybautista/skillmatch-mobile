// Basic smoke test: the login/register screen renders its tab toggle.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:skillmatch/screens/auth/auth_screen.dart';
import 'package:skillmatch/services/auth_service.dart';

void main() {
  testWidgets('Auth screen shows the login/register tab toggle', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthService(),
        child: const MaterialApp(home: AuthScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Sign Up'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
  });
}
