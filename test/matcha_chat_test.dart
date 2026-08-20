import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:skillmatch/models/app_user.dart';
import 'package:skillmatch/models/chat_message.dart';
import 'package:skillmatch/screens/chatbot/chat_destinations.dart';
import 'package:skillmatch/screens/chatbot/matcha_chat_screen.dart';
import 'package:skillmatch/services/auth_service.dart';
import 'package:skillmatch/services/chatbot_service.dart';

class _FakeChatbotService extends ChatbotService {
  _FakeChatbotService({this.reply, this.error});

  final ChatReply? reply;
  final Object? error;

  String? lastMessage;
  List<ChatMessage>? lastHistory;

  @override
  Future<ChatReply> send(String message, List<ChatMessage> history) async {
    lastMessage = message;
    lastHistory = history;
    if (error != null) throw error!;
    return reply ?? ChatReply(answer: 'ok', cards: const []);
  }
}

/// A signed-in session for the screen to read the role from.
AuthService _auth(String role) {
  return AuthService()
    ..currentUser = AppUser(
      id: 1,
      name: role == 'company' ? 'Creatix Studio' : 'Jayby Bautista',
      email: 'someone@skillmatch.test',
      role: role,
      status: 'active',
    );
}

Future<void> _pump(
  WidgetTester tester,
  ChatbotService service, {
  String role = 'student',
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthService>.value(
      value: _auth(role),
      child: MaterialApp(home: MatchaChatScreen(service: service)),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('opens on the welcome state', (tester) async {
    await _pump(tester, _FakeChatbotService());

    expect(find.text('Hello, I am Matcha!'), findsOneWidget);
    expect(find.text('Ask anything'), findsOneWidget);
  });

  testWidgets('a company gets company prompts, not student ones', (
    tester,
  ) async {
    await _pump(tester, _FakeChatbotService(), role: 'company');

    expect(find.text('How do I post an internship?'), findsOneWidget);
    expect(find.text('Where do I review applications?'), findsOneWidget);
    // A company has no resume and no match rate.
    expect(find.text('Resume Tips'), findsNothing);
    expect(find.text('How to improve my match rate?'), findsNothing);
  });

  testWidgets('a student still gets the student prompts', (tester) async {
    await _pump(tester, _FakeChatbotService());

    expect(find.text('Resume Tips'), findsOneWidget);
    expect(find.text('How do I post an internship?'), findsNothing);
  });

  testWidgets('sending a message shows it and then the reply', (tester) async {
    final service = _FakeChatbotService(
      reply: ChatReply(answer: 'Here is your answer', cards: const []),
    );
    await _pump(tester, service);

    // Deliberately not one of the suggestion chips, so the assertion below
    // matches the bubble and nothing else.
    await tester.enterText(
      find.byType(TextField),
      'Which companies are hiring?',
    );
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    await tester.pump();

    expect(service.lastMessage, 'Which companies are hiring?');
    // The message being sent must not also be in the history.
    expect(service.lastHistory, isEmpty);
    expect(find.text('Which companies are hiring?'), findsOneWidget);
    expect(find.text('Here is your answer'), findsOneWidget);
    expect(find.text('Hello, I am Matcha!'), findsNothing);
  });

  testWidgets('a navigation answer renders its destination card', (
    tester,
  ) async {
    final service = _FakeChatbotService(
      reply: ChatReply(
        answer: 'Open **Applications** to take it.',
        cards: [
          ChatCard(
            title: 'My Applications',
            subtitle: 'Competency tests assigned to you',
            screen: 'applications',
          ),
        ],
      ),
    );
    await _pump(tester, service);

    await tester.enterText(
      find.byType(TextField),
      'how do i take an assessment',
    );
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    await tester.pump();

    expect(find.text('My Applications'), findsOneWidget);
    expect(find.text('Competency tests assigned to you'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('a tapped suggestion is sent as a message', (tester) async {
    final service = _FakeChatbotService();
    await _pump(tester, service);

    await tester.tap(find.text('Resume Tips'));
    await tester.pump();
    await tester.pump();

    expect(service.lastMessage, 'Resume Tips');
  });

  testWidgets('a failed send reports it in the conversation', (tester) async {
    final service = _FakeChatbotService(error: Exception('offline'));
    await _pump(tester, service);

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining("couldn't reach the server"), findsOneWidget);
  });

  group('chat destinations', () {
    test('every screen key the app supports resolves', () {
      for (final key in [
        'home',
        'internship_search',
        'top_matches',
        'bookmarks',
        'applications',
        'placement',
        'resume_builder',
        'profile',
        'settings',
        'requirements',
        'roadmap',
      ]) {
        expect(
          chatDestinationFor(key),
          isNotNull,
          reason: '$key should navigate',
        );
      }
    });

    test(
      'junk destinations resolve to nothing rather than the wrong place',
      () {
        expect(chatDestinationFor(''), isNull);
        expect(chatDestinationFor('not_a_screen'), isNull);
      },
    );

    test('every company capability the backend offers can be opened', () {
      // These ids are ChatbotNavigationService's `company` capability list.
      // A card Matcha hands a company on the web has to land somewhere in the
      // app too, so any id added there needs one here.
      const companyScreens = [
        'company_internships',
        'company_internship_create',
        'company_applications',
        'company_candidates',
        'company_bookmarks',
        'company_assessments',
        'company_placements',
        'company_records',
        'company_analytics',
        'company_my_profile',
      ];

      for (final screen in companyScreens) {
        expect(
          chatDestinationFor(screen),
          isNotNull,
          reason: '$screen has no destination',
        );
      }
    });

    test("a company's own profile is not the public-profile destination", () {
      // 'company_profile' means "some company's public page, by id" and needs
      // that id; the signed-in company's own editable profile is a different
      // screen, so the two must not share an id.
      expect(chatDestinationFor('company_profile'), isNotNull);
      expect(chatDestinationFor('company_my_profile'), isNotNull);
    });

    test('notifications now has a real screen to land on', () {
      expect(chatDestinationFor('notifications'), isNotNull);
      expect(unavailableReasonFor('notifications'), isNull);
    });
  });

  group('history', () {
    test('is trimmed to the last 10 turns, as the web does', () {
      final history = List.generate(
        30,
        (i) => ChatMessage(
          role: i.isEven ? ChatRole.user : ChatRole.assistant,
          text: 'm$i',
          sentAt: DateTime.now(),
        ),
      );

      final recent = history.length > ChatbotService.historyLimit
          ? history.sublist(history.length - ChatbotService.historyLimit)
          : history;

      expect(recent, hasLength(10));
      expect(recent.first.text, 'm20');
      expect(recent.last.text, 'm29');
    });

    test('a turn serialises to the role/content shape the API expects', () {
      final message = ChatMessage(
        role: ChatRole.user,
        text: 'hi',
        sentAt: DateTime.now(),
      );
      expect(message.toHistoryJson(), {'role': 'user', 'content': 'hi'});
    });
  });
}
