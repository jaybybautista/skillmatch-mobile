import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import 'profile_photo_picker.dart';

/// Full-screen, pinch-to-zoom view of a profile photo, opened by tapping the
/// avatar. Pops `true` when the photo was replaced, so the profile can
/// refresh.
class ImageViewerScreen extends StatelessWidget {
  const ImageViewerScreen({
    super.key,
    required this.imageUrl,
    this.heroTag = 'profile-photo',
    this.title,
    this.allowChange = true,
  });

  final String imageUrl;
  final String heroTag;
  final String? title;
  final bool allowChange;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: title != null ? Text(title!, style: AppFonts.title(color: Colors.white, fontSize: 16)) : null,
      ),
      body: Center(
        child: Hero(
          tag: heroTag,
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const Center(child: CircularProgressIndicator(color: Colors.white)),
              errorBuilder: (context, error, stackTrace) => const Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Could not load this photo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: allowChange
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final changed = await pickAndUploadProfilePhoto(context);
                    if (changed && context.mounted) Navigator.of(context).pop(true);
                  },
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: const Text('Change Photo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
