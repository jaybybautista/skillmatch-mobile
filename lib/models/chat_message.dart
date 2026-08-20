/// Matcha chat models, mirroring the payload the web panel exchanges with
/// ChatbotController.
library;

/// A destination Matcha suggested — rendered as a tappable card under its
/// reply, the same as the web's `.chatbot-card`.
///
/// The web navigates using [url]; the app uses [screen], a platform-neutral id
/// that ChatbotNavigationService assigns so both stay in step.
class ChatCard {
  ChatCard({
    required this.title,
    required this.subtitle,
    required this.screen,
    this.url,
  });

  final String title;
  final String subtitle;
  final String screen;
  final String? url;

  factory ChatCard.fromJson(Map<String, dynamic> json) => ChatCard(
    title: json['title'] as String? ?? '',
    subtitle: json['subtitle'] as String? ?? '',
    screen: json['screen'] as String? ?? '',
    url: json['url'] as String?,
  );
}

enum ChatRole { user, assistant }

class ChatMessage {
  ChatMessage({
    required this.role,
    required this.text,
    required this.sentAt,
    this.cards = const [],
    this.isPending = false,
    this.hasFailed = false,
  });

  final ChatRole role;
  final String text;
  final DateTime sentAt;
  final List<ChatCard> cards;

  /// True while Matcha is still composing a reply (the typing bubble).
  final bool isPending;

  /// True when the request failed, so the bubble can offer a retry.
  final bool hasFailed;

  bool get isUser => role == ChatRole.user;

  /// The shape the API expects for prior turns.
  Map<String, String> toHistoryJson() => {
    'role': role == ChatRole.user ? 'user' : 'assistant',
    'content': text,
  };

  /// "10:24 AM"
  String get timeLabel {
    final hour24 = sentAt.hour;
    final hour = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minute = sentAt.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${hour24 < 12 ? 'AM' : 'PM'}';
  }
}

/// One reply from the chatbot endpoint.
class ChatReply {
  ChatReply({required this.answer, required this.cards});

  final String answer;
  final List<ChatCard> cards;

  factory ChatReply.fromJson(Map<String, dynamic> json) => ChatReply(
    answer:
        json['answer'] as String? ??
        "I didn't get a response. Please try again.",
    cards: (json['cards'] as List? ?? const [])
        .map((e) => ChatCard.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
