import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/student_profile.dart';
import '../../services/profile_service.dart';
import '../../services/resume_service.dart';
import '../../widgets/primary_button.dart';
import 'resume_sections_screen.dart';

/// Uploads a PDF/JPG/PNG resume — or reuses the student's already-uploaded
/// profile resume — to the same server-side Tesseract OCR + Groq parsing
/// pipeline the web app's "Import" feature uses, then opens the new resume.
class ImportResumeScreen extends StatefulWidget {
  const ImportResumeScreen({super.key});

  @override
  State<ImportResumeScreen> createState() => _ImportResumeScreenState();
}

class _ImportResumeScreenState extends State<ImportResumeScreen> {
  final _resumeService = ResumeService();
  late final Future<ResumeInfo?> _profileResumeFuture = _loadProfileResume();

  bool _useProfileResume = false;
  PlatformFile? _pickedFile;
  bool _isImporting = false;

  Future<ResumeInfo?> _loadProfileResume() async {
    try {
      final profile = await ProfileService().fetchStudentProfile();
      if (profile.resume != null && mounted) {
        setState(() => _useProfileResume = true);
      }
      return profile.resume;
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _pickedFile = result.files.single;
      _useProfileResume = false;
    });
  }

  Future<void> _import() async {
    setState(() => _isImporting = true);
    try {
      final resume = await _resumeService.importResume(
        filePath: _pickedFile?.path,
        useProfileResume: _useProfileResume,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ResumeSectionsScreen(resumeId: resume.id)));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resume imported! Review the extracted info and make any corrections needed.')),
      );
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong reading that file. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canImport = !_isImporting && (_useProfileResume || _pickedFile != null);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Import Resume', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<ResumeInfo?>(
        future: _profileResumeFuture,
        builder: (context, snapshot) {
          final isLoading = snapshot.connectionState != ConnectionState.done;
          final profileResume = snapshot.data;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Upload a resume file and we\'ll read it with OCR and AI to pre-fill a new resume for you to review and edit.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 20),
              if (isLoading)
                const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
              else ...[
                if (profileResume != null) ...[
                  _SourceOption(
                    title: 'Use my uploaded profile resume',
                    subtitle: profileResume.filename,
                    icon: Icons.description_outlined,
                    selected: _useProfileResume,
                    onTap: () => setState(() {
                      _useProfileResume = true;
                      _pickedFile = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                ],
                _SourceOption(
                  title: _pickedFile != null ? _pickedFile!.name : 'Choose a PDF, JPG, or PNG file',
                  subtitle: _pickedFile != null ? 'Tap to choose a different file' : 'Max size 8 MB',
                  icon: Icons.upload_file_outlined,
                  selected: !_useProfileResume && _pickedFile != null,
                  onTap: _pickFile,
                ),
              ],
              const SizedBox(height: 28),
              PrimaryButton(
                label: _isImporting ? 'Reading your resume…' : 'Import',
                isLoading: _isImporting,
                onPressed: canImport ? _import : null,
              ),
              if (_isImporting) ...[
                const SizedBox(height: 12),
                const Text(
                  'This can take up to a minute for scanned files.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SourceOption extends StatelessWidget {
  const _SourceOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.chipBackground : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? AppColors.primary : AppColors.textMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: selected ? AppColors.primary : AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppColors.primary : AppColors.border,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
