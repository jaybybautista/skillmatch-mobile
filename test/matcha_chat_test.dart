import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillmatch/models/chat_message.dart';
import 'package:skillmatch/screens/chatbot/chat_destinations.dart';
import 'package:skillmatch/screens/chatbot/matcha_chat_screen.dart';
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

Future<void> _pump(WidgetTester tester, ChatbotService service) async {
  await tester.pumpWidget(MaterialApp(home: MatchaChatScreen(service: service)));
  await tester.pump();
}

void main() {
  testWidgets('opens on the welcome state', (tester) async {
    await _pump(tester, _FakeChatbotService());

    expect(find.text('Hello, I am Matcha!'), findsOneWidget);
    expect(find.text('Ask anything'), findsOneWidget);
  });

  testWidgets('sending a message shows it and then the reply', (tester) async {
    final service = _FakeChatbotService(
      reply: ChatReply(answer: 'Here is your answer', cards: const []),
    );
    await _pump(tester, service);

    // Deliberately not one of the suggestion chips, so the assertion below
    // matches the bubble and nothing else.
    await tester.enterText(find.byType(TextField), 'Which companies are hiring?');
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

  testWidgets('a navigation answer renders its destination card', (tester) async {
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

    await tester.enterText(find.byType(TextField), 'how do i take an assessment');
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
      ]) {
        expect(chatDestinationFor(key), isNotNull, reason: '$key should navigate');
      }
    });

    test('screens the app lacks resolve to nothing rather than the wrong place', () {
      // These exist on the web only; the chat says so instead of guessing.
      expect(chatDestinationFor('roadmap'), isNull);
      expect(chatDestinationFor('notifications'), isNull);
      expect(chatDestinationFor('requirements'), isNull);
      expect(chatDestinationFor('company_analytics'), isNull);
      expect(chatDestinationFor(''), isNull);
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
      final message = ChatMessage(role: ChatRole.user, text: 'hi', sentAt: DateTime.now());
      expect(message.toHistoryJson(), {'role': 'user', 'content': 'hi'});
    });
  });
}
