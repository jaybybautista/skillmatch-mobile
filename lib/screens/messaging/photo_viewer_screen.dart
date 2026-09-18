import 'package:flutter/material.dart';

/// Full-screen photo from a message: pinch to zoom, tap the X to close.
/// Attachments need the bearer token, hence [headers].
class PhotoViewerScreen extends StatelessWidget {
  const PhotoViewerScreen({
    super.key,
    required this.url,
    this.headers = const {},
    this.title,
  });

  final String url;
  final Map<String, String> headers;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: title == null ? null : Text(title!, style: const TextStyle(fontSize: 14)),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 5,
          child: Image.network(
            url,
            headers: headers,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : const CircularProgressIndicator(color: Colors.white),
            errorBuilder: (_, _, _) => const Text(
              'Could not load this photo.',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
      ),
    );
  }
}
