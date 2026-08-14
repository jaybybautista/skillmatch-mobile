import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/app_theme.dart';
import '../../core/file_share.dart';
import '../../models/requirement.dart';

typedef PreviewLoader = Future<RequirementPreview> Function();
typedef DownloadLoader = Future<List<int>> Function();

/// Reads one document — either a coordinator's template or a student's own
/// upload — the same way the web's `document-viewer.blade.php` does: a PDF
/// (converted server-side when the source wasn't already one) renders inline,
/// an image renders inline, and anything else falls back to a Download
/// button, since neither platform can display it in place.
class RequirementViewerScreen extends StatefulWidget {
  const RequirementViewerScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.loadPreview,
    required this.loadDownload,
    required this.downloadFilename,
  });

  final String title;
  final String subtitle;
  final PreviewLoader loadPreview;
  final DownloadLoader loadDownload;
  final String downloadFilename;

  @override
  State<RequirementViewerScreen> createState() => _RequirementViewerScreenState();
}

class _RequirementViewerScreenState extends State<RequirementViewerScreen> {
  late final Future<RequirementPreview> _future = widget.loadPreview();
  bool _isDownloading = false;

  Future<void> _download() async {
    setState(() => _isDownloading = true);
    try {
      final bytes = await widget.loadDownload();
      await shareFileBytes(bytes, widget.downloadFilename);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not download this file. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(widget.subtitle, style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: _isDownloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.download_outlined, color: Colors.white),
            tooltip: 'Download',
            onPressed: _isDownloading ? null : _download,
          ),
        ],
      ),
      body: FutureBuilder<RequirementPreview>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _Fallback(message: 'Could not load this file. Please try again.', onDownload: _download);
          }

          final preview = snapshot.data!;
          switch (preview.kind) {
            case PreviewKind.pdf:
              return PdfPreview(
                build: (format) async => Uint8List.fromList(preview.bytes!),
                useActions: false,
                canDebug: false,
              );
            case PreviewKind.image:
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: Center(child: Image.memory(Uint8List.fromList(preview.bytes!))),
              );
            case PreviewKind.none:
              return _Fallback(
                message: preview.message ?? 'This file cannot be shown here.',
                onDownload: _download,
              );
          }
        },
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.message, required this.onDownload});

  final String message;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file_outlined, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onDownload,
              icon: const Icon(Icons.download_outlined),
              label: const Text('Download instead'),
            ),
          ],
        ),
      ),
    );
  }
}
