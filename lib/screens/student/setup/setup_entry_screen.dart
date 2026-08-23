import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../../../core/error_message.dart';
import '../../../models/profile_setup.dart';
import '../../../services/auth_service.dart';
import '../../../services/profile_setup_service.dart';
import '../../../widgets/circle_back_button.dart';
import 'resume_scan_screen.dart';
import 'setup_wizard_screen.dart';

/// The first screen a new student sees: upload a resume to have the profile
/// filled in, or skip straight to typing it themselves.
///
/// Mirrors the web wizard's entry page, including the promise that nothing is
/// saved without review.
class SetupEntryScreen extends StatefulWidget {
  const SetupEntryScreen({super.key, this.service});

  final ProfileSetupService? service;

  @override
  State<SetupEntryScreen> createState() => _SetupEntryScreenState();
}

class _SetupEntryScreenState extends State<SetupEntryScreen> {
  late final ProfileSetupService _service =
      widget.service ?? ProfileSetupService();

  String? _fileName;
  String? _filePath;
  bool _isUploading = false;

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
    );

    final picked = result?.files.single;
    if (picked?.path == null) return;

    setState(() {
      _fileName = picked!.name;
      _filePath = picked.path;
    });
  }

  Future<void> _scan() async {
    final path = _filePath;
    if (path == null || _isUploading) return;

    setState(() => _isUploading = true);

    // The scan screen sits over the request for its whole duration, so the
    // student sees progress rather than a frozen button.
    final scanRoute = MaterialPageRoute<void>(
      builder: (_) => ResumeScanScreen(fileName: _fileName ?? 'resume'),
    );
    unawaitedPush(scanRoute);

    try {
      final parsed = await _service.uploadResume(path);
      if (!mounted) return;

      // Drop the scan screen, then continue into the wizard prefilled.
      Navigator.of(context).pop();
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SetupWizardScreen(
            service: _service,
            parsed: parsed,
            resumeName: _fileName,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // close the scan screen
      setState(() => _isUploading = false);

      final message = e is ApiException
          ? e.message
          : 'Could not read that file. Please try a clearer scan or fill in manually.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void unawaitedPush(Route<void> route) {
    Navigator.of(context).push(route);
  }

  /// Leaves setup for later. The same call the wizard's Skip makes, so the
  /// student is marked as having skipped rather than half-finished.
  Future<void> _skip() async {
    if (_isUploading) return;
    setState(() => _isUploading = true);

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await _service.skip();
      if (!mounted) return;
      context.read<AuthService>().invalidateSetupState();
      navigator.popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            messageForError(e, 'Could not skip setup. Please try again.'),
          ),
        ),
      );
    }
  }

  /// Back out of setup altogether.
  ///
  /// This screen is the first thing after signing in, so there is no earlier
  /// screen to return to — the only thing behind it is the login page. Rather
  /// than leave Back doing nothing (which is what it would do here), it signs
  /// out, and asks first because that isn't what Back usually means.
  ///
  /// Nothing is lost either way: each wizard step saves as it is completed,
  /// so signing in again picks up where this left off.
  Future<void> _leaveSetup() async {
    if (_isUploading) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave setup?'),
        content: const Text(
          "You'll be signed out. Anything you've already filled in is kept, "
          'and you can finish setting up next time you log in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // The session gate at the root shows the login screen as soon as the
    // session clears, so there is nothing to navigate to by hand.
    await context.read<AuthService>().logout();
  }

  Future<void> _fillManually() async {
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            SetupWizardScreen(service: _service, parsed: ParsedResume.empty()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leaveSetup();
      },
      child: _buildScreen(),
    );
  }

  Widget _buildScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.primary,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                child: Row(
                  children: [
                    // Always given a callback: CircleBackButton falls back to
                    // maybePop() when handed null, which would be the wrong
                    // thing entirely. _leaveSetup ignores taps while a scan is
                    // in flight.
                    CircleBackButton(onPressed: _leaveSetup, filled: true),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Set up your profile',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.title(
                          fontSize: 19,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _isUploading ? null : _skip,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      child: const Text(
                        'Skip for now',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              children: [
                Text('Upload your resume', style: AppFonts.title(fontSize: 18)),
                const SizedBox(height: 4),
                const Text(
                  "We'll auto-fill your profile from it",
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FB),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ResumeDropZone(
                    fileName: _fileName,
                    onPick: _pick,
                    onClear: () => setState(() {
                      _fileName = null;
                      _filePath = null;
                    }),
                  ),
                ),
                if (_fileName != null) ...[
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: _isUploading ? null : _scan,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Upload & Scan Resume'),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF1FD),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "We'll scan your resume and auto-fill your profile. You can review "
                          'everything before saving.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.primary,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                Center(
                  child: TextButton(
                    onPressed: _isUploading ? null : _fillManually,
                    child: const Text(
                      'or fill in manually',
                      style: TextStyle(decoration: TextDecoration.underline),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
