import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../core/app_theme.dart';
import '../core/file_share.dart';
import '../screens/messaging/photo_viewer_screen.dart';

/// The certificate verification badge from the web (`x-cert-badge`):
/// Verified (the OCR read the file and it matches what was typed),
/// Unverified (file present but no match, or unreadable), or No proof file.
/// [detail] is the reason, shown on tap. [fileUrl] adds a "View file" link.
class CertBadge extends StatelessWidget {
  const CertBadge({
    super.key,
    required this.status,
    required this.label,
    this.detail,
    this.fileUrl,
    this.compact = false,
  });

  /// verified | unverified | no_file
  final String status;
  final String label;
  final String? detail;
  final String? fileUrl;
  final bool compact;

  bool get isVerified => status == 'verified';

  @override
  Widget build(BuildContext context) {
    final (color, bg, border) = switch (status) {
      'verified' => (const Color(0xFF1A7F4B), const Color(0xFFEAFAF1), const Color(0xFFC9EFD9)),
      'unverified' => (const Color(0xFFB87700), const Color(0xFFFFF4E5), const Color(0xFFFBE2B6)),
      _ => (AppColors.textMuted, Colors.white, AppColors.border),
    };

    return Wrap(
      spacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Tooltip(
          message: detail ?? label,
          triggerMode: TooltipTriggerMode.tap,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: 2),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isVerified) Icon(Icons.check, size: 11, color: color),
                if (isVerified) const SizedBox(width: 3),
                Text(label, style: TextStyle(fontSize: compact ? 10 : 10.5, fontWeight: FontWeight.w700, color: color)),
              ],
            ),
          ),
        ),
        if (fileUrl != null && fileUrl!.isNotEmpty)
          GestureDetector(
            onTap: () => openCertificateFile(context, fileUrl!),
            child: Text(
              'View file',
              style: TextStyle(fontSize: compact ? 10.5 : 11.5, fontWeight: FontWeight.w600, color: AppColors.primary),
            ),
          ),
      ],
    );
  }
}

/// Opens the proof file: photos in the in-app viewer, PDFs through the
/// share sheet (so any PDF app on the phone can show it).
Future<void> openCertificateFile(BuildContext context, String url) async {
  final lower = url.toLowerCase().split('?').first;
  if (lower.endsWith('.pdf')) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Opening the certificate file…')));
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        await shareFileBytes(response.bodyBytes, lower.split('/').last);
        return;
      }
    } catch (_) {}
    messenger.showSnackBar(const SnackBar(content: Text('Could not open the certificate file.')));
    return;
  }
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => PhotoViewerScreen(url: url, title: 'Certificate')),
  );
}

/// Picks the certificate proof: a photo from the camera or gallery, or a
/// PDF / image file. Returns the local path, or null when dismissed.
Future<String?> pickCertificateFile(BuildContext context) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Take a photo of the certificate'), onTap: () => Navigator.pop(context, 'camera')),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choose a photo'), onTap: () => Navigator.pop(context, 'gallery')),
          ListTile(leading: const Icon(Icons.picture_as_pdf_outlined), title: const Text('Choose a PDF or image file'), onTap: () => Navigator.pop(context, 'file')),
          const SizedBox(height: 6),
        ],
      ),
    ),
  );
  if (choice == null) return null;

  if (choice == 'file') {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png']);
    return result?.files.single.path;
  }
  final picked = await ImagePicker().pickImage(
    source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
    imageQuality: 90,
    maxWidth: 2400,
  );
  return picked?.path;
}
