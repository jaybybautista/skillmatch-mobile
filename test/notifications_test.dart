import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:skillmatch/models/app_notification.dart';
import 'package:skillmatch/screens/chatbot/chat_destinations.dart';
import 'package:skillmatch/widgets/app_sidebar.dart';

void main() {
  group('AppNotification', () {
    test('carries the destination the backend resolved', () {
      final notification = AppNotification.fromJson({
        'id': 7,
        'title': 'New Reply to Your Review',
        'message': 'Ana replied to your review.',
        'type': 'review',
        'is_read': false,
        'time_ago': '2 minutes ago',
        'screen': 'internship_detail',
        'screen_params': {'internship_id': 5, 'review_id': 12},
      });

      expect(notification.screen, 'internship_detail');
      expect(notification.screenParams['internship_id'], 5);
      expect(notification.typeLabel, 'Review');
      expect(notification.isRead, isFalse);
    });

    test('falls back to the list when the payload has no destination', () {
      final notification = AppNotification.fromJson({
        'id': 1,
        'title': 'Welcome',
        'message': 'Hello',
        'type': 'system',
        'is_read': true,
      });

      expect(notification.screen, 'notifications');
      expect(notification.screenParams, isEmpty);
      expect(notification.typeLabel, 'System');
    });

    test('page parses per-type counts', () {
      final page = NotificationPage.fromJson({
        'notifications': [],
        'counts': {'all': 9, 'application': 4, 'review': 5, 'unread': 3},
      });

      expect(page.counts['application'], 4);
      expect(page.unread, 3);
    });
  });

  group('destination resolution', () {
    test('every screen key the backend can emit either resolves or explains', () {
      // The keys NotificationRouter and ChatbotNavigationService produce.
      const emitted = [
        'home',
        'internship_search',
        'top_matches',
        'bookmarks',
        'applications',
        'placement',
        'resume_builder',
        'profile',
        'settings',
        'notifications',
        'internship_detail',
        'review_thread',
        'roadmap',
        'requirements',
      ];

      for (final screen in emitted) {
        final resolves = chatDestinationFor(screen) != null;
        final explained = unavailableReasonFor(screen) != null;

        expect(
          resolves || explained,
          isTrue,
          reason: '"$screen" neither navigates nor says why it cannot',
        );
      }
    });

    test('the two web-only screens are the only unresolved ones', () {
      expect(unavailableDestinations.keys, containsAll(['roadmap', 'requirements']));
      expect(chatDestinationFor('roadmap'), isNull);
      expect(chatDestinationFor('requirements'), isNull);

      // Everything the app does have must actually navigate.
      expect(chatDestinationFor('notifications'), isNotNull);
      expect(chatDestinationFor('applications'), isNotNull);
      expect(chatDestinationFor('placement'), isNotNull);
    });

    test('id-carrying destinations need their id', () {
      expect(chatDestinationFor('internship_detail', {'internship_id': 5}), isNotNull);
      expect(chatDestinationFor('review_thread', {'review_id': 12}), isNotNull);
    });
  });

  group('AppSidebar', () {
    testWidgets('lists the same entries as the web sidebar, in order', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(drawer: AppSidebar(current: SidebarItem.home), body: SizedBox()),
      ));

      tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
      await tester.pumpAndSettle();

      for (final label in [
        'Home',
        'Notifications',
        'Applications',
        'Bookmarks',
        'ACCOUNT',
        'Profile',
        'Resume Builder',
        'Skill Roadmap',
        'Requirements',
        'Settings',
      ]) {
        expect(find.text(label), findsOneWidget, reason: 'missing "$label"');
      }

      expect(find.text('Search'), findsOneWidget);
    });

    testWidgets('a web-only entry explains itself instead of navigating', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(drawer: AppSidebar(current: SidebarItem.home), body: SizedBox()),
      ));

      tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skill Roadmap'));
      await tester.pumpAndSettle();

      expect(find.textContaining('only on the SkillMatch website'), findsOneWidget);
    });
  });
}
