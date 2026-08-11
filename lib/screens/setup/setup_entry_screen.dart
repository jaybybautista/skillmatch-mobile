import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/profile_setup.dart';
import '../../services/profile_setup_service.dart';
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
  late final ProfileSetupService _service = widget.service ?? ProfileSetupService();

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void unawaitedPush(Route<void> route) {
    Navigator.of(context).push(route);
  }

  Future<void> _fillManually() async {
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SetupWizardScreen(service: _service, parsed: ParsedResume.empty()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.primary,
            child: SafeArea(
              bottom: false,
              child: const Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 18),
                child: Row(
                  children: [
                    Image(image: AssetImage('assets/logo.png'), width: 38),
                    SizedBox(width: 12),
                    Text(
                      'Set up your profile',
                      style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
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
                const Text(
                  'Upload your resume',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "We'll scan your resume and auto-fill your profile. You can review "
                          'everything before saving.',
                          style: TextStyle(fontSize: 13, color: AppColors.primary, height: 1.45),
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
