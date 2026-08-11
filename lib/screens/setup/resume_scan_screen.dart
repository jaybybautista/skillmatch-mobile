import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

/// The "Extracting your details…" screen shown while a resume is being read.
///
/// OCR plus an AI round trip is genuinely slow — often 10–30 seconds — so this
/// keeps the wait explained and visibly alive rather than freezing on a
/// spinner. It's purely presentational; the caller owns the request.
class ResumeScanScreen extends StatefulWidget {
  const ResumeScanScreen({super.key, required this.fileName});

  final String fileName;

  @override
  State<ResumeScanScreen> createState() => _ResumeScanScreenState();
}

class _ResumeScanScreenState extends State<ResumeScanScreen> with TickerProviderStateMixin {
  /// Drives the pulsing halo behind the scan badge.
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();

  /// Drives the line sweeping down the badge, like a document scanner.
  late final AnimationController _sweep =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B3FCB), Color(0xFF10237A), Color(0xFF071033)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 240,
                  height: 240,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_pulse, _sweep]),
                    builder: (context, _) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Two haloes half a cycle apart, so one is always
                          // expanding as the other fades.
                          _Halo(progress: _pulse.value),
                          _Halo(progress: (_pulse.value + 0.5) % 1.0),
                          Container(
                            width: 108,
                            height: 108,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.20),
                              borderRadius: BorderRadius.circular(26),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                const Icon(Icons.crop_free, size: 46, color: Colors.white),
                                Align(
                                  alignment: Alignment(0, _sweep.value * 2 - 1),
                                  child: Container(
                                    width: 66,
                                    height: 2,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 26),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.description_outlined, size: 16, color: Colors.white),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 200),
                        child: Text(
                          widget.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                const Text(
                  'Extracting your details...',
                  style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'This usually takes a few seconds',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One expanding, fading ring.
class _Halo extends StatelessWidget {
  const _Halo({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final size = 120.0 + progress * 110;

    return Opacity(
      opacity: (1 - progress) * 0.35,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.14),
        ),
      ),
    );
  }
}

/// The upload card used on the entry screen and on step 1.
class ResumeDropZone extends StatelessWidget {
  const ResumeDropZone({
    super.key,
    required this.fileName,
    required this.onPick,
    required this.onClear,
  });

  final String? fileName;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (fileName != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF1FD),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.picture_as_pdf, color: Color(0xFFE03E3E)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Ready to upload',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 34),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Column(
          children: [
            Icon(Icons.cloud_upload_outlined, size: 34, color: AppColors.primary),
            SizedBox(height: 10),
            Text(
              'Tap to upload your resume',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
