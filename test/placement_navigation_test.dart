import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:skillmatch/screens/chatbot/chat_destinations.dart';
import 'package:skillmatch/services/auth_service.dart';
import 'package:skillmatch/widgets/app_sidebar.dart';

/// The drawer reads the signed-in user for its header, so it needs an
/// AuthService above it even with nobody signed in.
Widget _withAuth(Widget child) => ChangeNotifierProvider<AuthService>(
  create: (_) => AuthService(),
  child: MaterialApp(home: child),
);

void main() {
  testWidgets('My placement is in the sidebar, between Skill Roadmap and '
      'Requirements', (tester) async {
    await tester.pumpWidget(
      _withAuth(
        const Scaffold(drawer: AppSidebar(current: SidebarItem.placement)),
      ),
    );

    tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pumpAndSettle();

    expect(find.text('My placement'), findsOneWidget);

    // The same order the web sidebar uses, so someone moving between the two
    // finds it in the same place.
    final roadmap = tester.getTopLeft(find.text('Skill Roadmap')).dy;
    final placement = tester.getTopLeft(find.text('My placement')).dy;
    final requirements = tester.getTopLeft(find.text('Requirements')).dy;

    expect(placement, greaterThan(roadmap));
    expect(placement, lessThan(requirements));
  });

  test('a placement notification has somewhere to open', () {
    // The API tags a coordinator's placement notification `placement`, and
    // NotificationRouter turns that into the screen id below. Without an
    // entry here, tapping the notification would land on "coming soon".
    expect(chatDestinationFor('placement', const {}), isNotNull);
    expect(unavailableDestinations, isNot(contains('placement')));
  });
}
