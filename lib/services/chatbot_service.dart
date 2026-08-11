import '../core/api_client.dart';
import '../models/chat_message.dart';

/// Talks to ChatbotController — the same endpoint the web panel uses.
///
/// Navigation questions ("how do I take an assessment?") are answered by the
/// shared ChatbotNavigationService before the request ever reaches the AI
/// endpoint, so Matcha gives identical directions on both platforms.
class ChatbotService {
  final ApiClient _client = ApiClient.instance;

  /// The web sends the last 10 turns for context; matching that keeps replies
  /// consistent between platforms and the payload small.
  static const int historyLimit = 10;

  Future<ChatReply> send(String message, List<ChatMessage> history) async {
    final recent = history.where((m) => !m.isPending && !m.hasFailed).toList();
    final trimmed = recent.length > historyLimit
        ? recent.sublist(recent.length - historyLimit)
        : recent;

    // The AI call can be slow, so this uses the long timeout rather than the
    // standard one.
    final response = await _client.postLong(
      '/chatbot',
      {
        'message': message,
        'history': trimmed.map((m) => m.toHistoryJson()).toList(),
      },
      authenticated: true,
    );

    return ChatReply.fromJson(response);
  }
}
