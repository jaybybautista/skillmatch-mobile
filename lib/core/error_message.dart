import 'dart:io';

import 'api_client.dart';

/// The message to show for a failed request.
///
/// [ApiException] already carries something the server said; anything else is
/// a timeout, a dropped connection or a malformed response, which used to be
/// swallowed entirely — the action would do nothing and say nothing.
///
/// For the cases the server didn't explain, the underlying reason is named
/// rather than hidden behind "check your connection": a request that was
/// refused, timed out, or came back as something other than JSON are three
/// very different problems, and telling them apart is the difference between
/// a fixable report and a shrug.
String messageForError(Object error, String fallback) {
  if (error is ApiException) return error.message;

  final detail = describeError(error);
  return detail == null ? fallback : '$fallback\n($detail)';
}

/// A short, plain description of a non-API failure, or null when there is
/// nothing more useful to say than the caller's own fallback.
String? describeError(Object error) {
  if (error is SocketException) {
    // The host was unreachable — wrong address, server not running, or the
    // phone is on a different network to the machine serving the API.
    return 'could not reach the server at ${error.address?.host ?? 'the API address'}';
  }

  if (error is HttpException) return 'the connection dropped';

  if (error is FormatException) {
    // Usually an HTML error page where JSON was expected.
    return 'the server sent something the app could not read';
  }

  final text = error.toString().trim();
  if (text.isEmpty || text == 'Exception') return null;

  // Keep it to one line: this goes in a snackbar, not a log.
  final firstLine = text.split('\n').first;
  return firstLine.length > 120 ? '${firstLine.substring(0, 117)}…' : firstLine;
}
