import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/app_navigation.dart';
import '../../../core/app_theme.dart';
import '../../../models/resume.dart';
import '../../../services/resume_service.dart';
import '../../../widgets/app_bottom_nav.dart';
import '../../../widgets/primary_button.dart';
import 'import_resume_screen.dart';
import 'resume_sections_screen.dart';
import '../../../widgets/app_sidebar.dart';

/// Resume list — GET/POST/rename/delete /api/resumes, the same `resumes`
/// table the web app's Resume Builder index page reads and writes.
class ResumeListScreen extends StatefulWidget {
  const ResumeListScreen({super.key});

  @override
  State<ResumeListScreen> createState() => _ResumeListScreenState();
}

class _ResumeListScreenState extends State<ResumeListScreen> with WidgetsBindingObserver {
  final _service = ResumeService();
  late Future<List<ResumeSummary>> _future = _service.fetchResumes();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // A resume created or edited on the web has no way to push to this screen,
  // so re-fetch whenever the app comes back to the foreground — otherwise a
  // resume list opened before the web-side change would look "stuck".
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final future = _service.fetchResumes();
    setState(() => _future = future);
    await future;
  }

  Future<void> _openResume(int id) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResumeSectionsScreen(resumeId: id)));
    _refresh();
  }

  Future<void> _openImport() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ImportResumeScreen()));
    _refresh();
  }

  Future<void> _showAddResumeSheet() async {
    final existing = await _future;
    if (!mounted) return;
    final controller = TextEditingController(text: 'Resume ${existing.length + 1}');
    bool isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Text('Add Resume', style: AppFonts.title(color: AppColors.primary)),
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 12),
                  const Text('Title', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                  const SizedBox(height: 6),
                  TextField(controller: controller, autofocus: true),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PrimaryButton(
                          label: 'Save new story',
                          isLoading: isSaving,
                          onPressed: () async {
                            final title = controller.text.trim();
                            if (title.isEmpty) return;
                            setSheetState(() => isSaving = true);
                            try {
                              final resume = await _service.createResume(title);
                              if (!sheetContext.mounted) return;
                              Navigator.of(sheetContext).pop();
                              await _refresh();
                              if (!mounted) return;
                              _openResume(resume.id);
                            } on ApiException catch (e) {
                              setSheetState(() => isSaving = false);
                              if (sheetContext.mounted) {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(SnackBar(content: Text(e.message)));
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showResumeOptionsSheet(ResumeSummary resume) async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Text(resume.title, style: AppFonts.title(fontSize: 18, color: AppColors.primary)),
                const SizedBox(height: 8),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: AppColors.primary),
                  title: const Text('Rename'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _showRenameSheet(resume);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: AppColors.danger),
                  title: const Text('Delete'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _confirmDelete(resume);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showRenameSheet(ResumeSummary resume) async {
    final controller = TextEditingController(text: resume.title);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Rename Resume', style: AppFonts.title(fontSize: 18, color: AppColors.primary)),
              const SizedBox(height: 12),
              TextField(controller: controller, autofocus: true),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Save',
                onPressed: () async {
                  final title = controller.text.trim();
                  if (title.isEmpty) return;
                  Navigator.of(sheetContext).pop();
                  try {
                    await _service.renameResume(resume.id, title);
                    _refresh();
                  } on ApiException catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(ResumeSummary resume) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete resume?'),
        content: Text('"${resume.title}" will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.deleteResume(resume.id);
      _refresh();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppSidebar(current: SidebarItem.resumeBuilder),
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text('Resume Builder', style: AppFonts.title(color: Colors.white)),
        actions: [
          IconButton(icon: const Icon(Icons.upload_file_outlined), tooltip: 'Import Resume', onPressed: _openImport),
          IconButton(icon: const Icon(Icons.add), onPressed: _showAddResumeSheet),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<ResumeSummary>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError || !snapshot.hasData) {
              final message =
                  snapshot.error is ApiException ? (snapshot.error as ApiException).message : 'Could not load your resumes.';
              return ListView(
                padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
                children: [
                  Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
                  const SizedBox(height: 12),
                  Center(child: TextButton(onPressed: _refresh, child: const Text('Retry'))),
                ],
              );
            }

            final resumes = snapshot.data!;
            if (resumes.isEmpty) {
              return ListView(
                padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
                children: [
                  const Icon(Icons.description_outlined, size: 40, color: AppColors.textMuted),
                  const SizedBox(height: 12),
                  const Text(
                    'No resumes yet. Tap + to create your first one.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ],
              );
            }

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                for (final resume in resumes) ...[
                  _ResumeRow(
                    resume: resume,
                    onTap: () => _openResume(resume.id),
                    onMenuTap: () => _showResumeOptionsSheet(resume),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: AppBottomNav(currentIndex: 2, onSelect: (i) => handleAppNavTap(context, i)),
    );
  }
}

class _ResumeRow extends StatelessWidget {
  const _ResumeRow({required this.resume, required this.onTap, required this.onMenuTap});

  final ResumeSummary resume;
  final VoidCallback onTap;
  final VoidCallback onMenuTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF1F2F5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(resume.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              InkWell(
                onTap: onMenuTap,
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.more_vert, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
