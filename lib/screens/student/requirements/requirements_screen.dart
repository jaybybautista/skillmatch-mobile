import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/app_navigation.dart';
import '../../../core/app_theme.dart';
import '../../../core/file_share.dart';
import '../../../models/requirement.dart';
import '../../../services/requirement_service.dart';
import '../../../widgets/app_bottom_nav.dart';
import '../../../widgets/app_sidebar.dart';
import '../../../widgets/empty_results.dart';
import 'requirement_viewer_screen.dart';

/// Which set of files is on screen — the coordinator's original forms, or
/// the student's own uploaded copies. Kept as two separate tabs (rather than
/// one card mixing both) so tapping a card is never ambiguous about which
/// file — theirs or yours — it is about to open.
enum _RequirementsView {
  forms('Coordinator Forms'),
  uploads('My Uploads');

  const _RequirementsView(this.label);
  final String label;
}

/// OJT Requirements — GET /api/student/requirements, the same
/// `requirements`/`requirement_submissions` rows the web's Requirements page
/// reads and writes, so an upload made here shows up in the coordinator's
/// submissions grid immediately, and vice versa.
class RequirementsScreen extends StatefulWidget {
  const RequirementsScreen({super.key, this.service});

  final RequirementService? service;

  @override
  State<RequirementsScreen> createState() => _RequirementsScreenState();
}

class _RequirementsScreenState extends State<RequirementsScreen> {
  late final RequirementService _service = widget.service ?? RequirementService();

  bool _isLoading = true;
  Object? _error;
  List<RequirementItem> _items = const [];
  _RequirementsView _view = _RequirementsView.forms;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await _service.fetchAll();
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _isLoading = false;
      });
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _viewTemplate(RequirementItem item) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RequirementViewerScreen(
        title: item.title,
        subtitle: 'Original copy from your coordinator',
        loadPreview: () => _service.previewTemplate(item.id),
        loadDownload: () => _service.downloadTemplate(item.id),
        downloadFilename: item.originalFilename ?? item.title,
      ),
    ));
  }

  void _viewUpload(RequirementItem item) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RequirementViewerScreen(
        title: item.title,
        subtitle: 'Your uploaded copy',
        loadPreview: () => _service.previewUpload(item.id),
        loadDownload: () => _service.downloadUpload(item.id),
        downloadFilename: item.submission.originalFilename ?? item.title,
      ),
    ));
  }

  Future<void> _downloadTemplate(RequirementItem item) async {
    try {
      final bytes = await _service.downloadTemplate(item.id);
      await shareFileBytes(bytes, item.originalFilename ?? item.title);
    } on ApiException catch (e) {
      _notify(e.message);
    }
  }

  Future<void> _downloadUpload(RequirementItem item) async {
    try {
      final bytes = await _service.downloadUpload(item.id);
      await shareFileBytes(bytes, item.submission.originalFilename ?? item.title);
    } on ApiException catch (e) {
      _notify(e.message);
    }
  }

  Future<void> _upload(RequirementItem item) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['doc', 'docx', 'pdf', 'odt', 'rtf', 'jpg', 'jpeg', 'png'],
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;

    try {
      await _service.upload(item.id, path);
      _notify('File uploaded. Submit it when you are ready.');
      await _load();
    } on ApiException catch (e) {
      _notify(e.message);
    }
  }

  Future<void> _submit(RequirementItem item) async {
    try {
      await _service.submit(item.id);
      _notify('"${item.title}" submitted to your coordinator.');
      await _load();
    } on ApiException catch (e) {
      _notify(e.message);
    }
  }

  Future<void> _unsubmit(RequirementItem item) async {
    try {
      await _service.unsubmit(item.id);
      _notify('Submission withdrawn. Your file is still here.');
      await _load();
    } on ApiException catch (e) {
      _notify(e.message);
    }
  }

  Future<void> _confirmRemove(RequirementItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove upload?'),
        content: Text('This deletes your uploaded copy of "${item.title}". You can upload again later.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.removeUpload(item.id);
      _notify('Upload removed.');
      await _load();
    } on ApiException catch (e) {
      _notify(e.message);
    }
  }

  Future<void> _showSheet(String title, List<Widget> actions) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textDark),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              ...actions,
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// The Coordinator Forms tab's menu — only ever touches the official
  /// template plus the entry point to start (or replace) an upload for it.
  Future<void> _showTemplateActions(RequirementItem item) {
    return _showSheet(item.title, [
      if (item.hasTemplate) ...[
        _ActionTile(
          icon: Icons.visibility_outlined,
          label: 'View template',
          onTap: () => _closeThen(() => _viewTemplate(item)),
        ),
        _ActionTile(
          icon: Icons.download_outlined,
          label: 'Download template',
          onTap: () => _closeThen(() => _downloadTemplate(item)),
        ),
      ],
      _ActionTile(
        icon: Icons.upload_file_outlined,
        label: item.submission.hasUpload ? 'Replace my copy' : 'Upload my copy',
        onTap: () => _closeThen(() => _upload(item)),
      ),
    ]);
  }

  /// The My Uploads tab's menu — only ever touches the student's own copy,
  /// never the coordinator's template.
  Future<void> _showUploadActions(RequirementItem item) {
    return _showSheet(item.title, [
      _ActionTile(
        icon: Icons.visibility_outlined,
        label: 'View my copy',
        onTap: () => _closeThen(() => _viewUpload(item)),
      ),
      _ActionTile(
        icon: Icons.download_outlined,
        label: 'Download my copy',
        onTap: () => _closeThen(() => _downloadUpload(item)),
      ),
      _ActionTile(
        icon: Icons.sync_outlined,
        label: 'Replace my copy',
        onTap: () => _closeThen(() => _upload(item)),
      ),
      if (item.submission.isSubmitted)
        _ActionTile(
          icon: Icons.undo,
          label: 'Withdraw submission',
          onTap: () => _closeThen(() => _unsubmit(item)),
        )
      else
        _ActionTile(
          icon: Icons.send_outlined,
          label: 'Submit to coordinator',
          onTap: () => _closeThen(() => _submit(item)),
        ),
      _ActionTile(
        icon: Icons.delete_outline,
        label: 'Remove upload',
        color: AppColors.danger,
        onTap: () => _closeThen(() => _confirmRemove(item)),
      ),
    ]);
  }

  void _closeThen(VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppSidebar(current: SidebarItem.requirements),
      backgroundColor: AppColors.primaryDark,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: Row(
                children: [
                  Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white),
                      onPressed: Scaffold.of(context).openDrawer,
                      tooltip: 'Menu',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'OJT Requirements',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  _ViewTabs(selected: _view, onSelected: (view) => setState(() => _view = view)),
                  Expanded(child: RefreshIndicator(onRefresh: _load, child: _buildBody())),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(currentIndex: 3, onSelect: (i) => handleAppNavTap(context, i)),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
        children: [
          Text(
            _error is ApiException ? (_error as ApiException).message : 'Could not load your requirements.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          Center(child: TextButton(onPressed: _load, child: const Text('Retry'))),
        ],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        children: const [
          EmptyResults(
            icon: Icons.fact_check_outlined,
            title: 'No requirements published yet',
            hint: 'Your coordinator hasn\'t posted any OJT forms for your campus yet.',
          ),
        ],
      );
    }

    if (_view == _RequirementsView.uploads) {
      final uploaded = _items.where((item) => item.submission.hasUpload).toList();

      if (uploaded.isEmpty) {
        return ListView(
          children: const [
            EmptyResults(
              icon: Icons.upload_file_outlined,
              title: 'Nothing uploaded yet',
              hint: 'Switch to Coordinator Forms and upload your filled-in copy of one.',
            ),
          ],
        );
      }

      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        itemCount: uploaded.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = uploaded[index];
          return _UploadCard(
            item: item,
            onTap: () => _viewUpload(item),
            onMore: () => _showUploadActions(item),
          );
        },
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = _items[index];
        return _RequirementCard(
          item: item,
          onTap: () => _viewTemplate(item),
          onMore: () => _showTemplateActions(item),
        );
      },
    );
  }
}

class _ViewTabs extends StatelessWidget {
  const _ViewTabs({required this.selected, required this.onSelected});

  final _RequirementsView selected;
  final ValueChanged<_RequirementsView> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          for (final view in _RequirementsView.values) ...[
            Expanded(
              child: GestureDetector(
                onTap: () => onSelected(view),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: view == selected ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: view == selected ? AppColors.primary : AppColors.border),
                  ),
                  child: Text(
                    view.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: view == selected ? Colors.white : AppColors.textDark,
                    ),
                  ),
                ),
              ),
            ),
            if (view != _RequirementsView.values.last) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class _RequirementCard extends StatelessWidget {
  const _RequirementCard({required this.item, required this.onTap, required this.onMore});

  final RequirementItem item;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final iconStyle = _iconFor(item.fileKind);
    final status = _statusFor(item.submission);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: item.hasTemplate ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: iconStyle.background, borderRadius: BorderRadius.circular(10)),
                child: Icon(iconStyle.icon, color: iconStyle.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.updatedAtHuman == null
                          ? item.readableSize
                          : 'Modified ${item.updatedAtHuman} • ${item.readableSize}',
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(color: status.background, borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        status.label,
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: status.color),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
                onPressed: onMore,
                tooltip: 'Actions',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A row on the My Uploads tab — reads the submission's own file info
/// (filename, size, kind) rather than the template's, and always opens the
/// student's own copy on tap, never the coordinator's.
class _UploadCard extends StatelessWidget {
  const _UploadCard({required this.item, required this.onTap, required this.onMore});

  final RequirementItem item;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final submission = item.submission;
    final iconStyle = _iconFor(submission.fileKind ?? 'file');
    final status = _statusFor(submission);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: iconStyle.background, borderRadius: BorderRadius.circular(10)),
                child: Icon(iconStyle.icon, color: iconStyle.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      submission.originalFilename ?? 'Your uploaded copy',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                    ),
                    if (submission.updatedAtHuman != null || submission.readableSize != null)
                      Text(
                        [
                          if (submission.updatedAtHuman != null) 'Modified ${submission.updatedAtHuman}',
                          if (submission.readableSize != null) submission.readableSize!,
                        ].join(' • '),
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                      ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(color: status.background, borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        status.label,
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: status.color),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
                onPressed: onMore,
                tooltip: 'Actions',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, required this.onTap, this.color});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? AppColors.textDark;
    return ListTile(
      leading: Icon(icon, color: resolved),
      title: Text(label, style: TextStyle(color: resolved, fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }
}

class _IconStyle {
  const _IconStyle(this.icon, this.color, this.background);
  final IconData icon;
  final Color color;
  final Color background;
}

_IconStyle _iconFor(String kind) {
  switch (kind) {
    case 'pdf':
      return const _IconStyle(Icons.picture_as_pdf, Color(0xFFDC3B3B), Color(0xFFFDECEC));
    case 'sheet':
      return const _IconStyle(Icons.table_chart, Color(0xFF1A7F4B), Color(0xFFE9F8EF));
    case 'image':
      return const _IconStyle(Icons.image_outlined, Color(0xFF7C3AED), Color(0xFFF3EEFE));
    case 'doc':
      return const _IconStyle(Icons.description, Color(0xFF3D6EF5), Color(0xFFE8EEFF));
    default:
      return const _IconStyle(Icons.insert_drive_file_outlined, AppColors.textMuted, AppColors.chipBackground);
  }
}

class _StatusStyle {
  const _StatusStyle(this.label, this.color, this.background);
  final String label;
  final Color color;
  final Color background;
}

_StatusStyle _statusFor(RequirementSubmissionInfo submission) {
  if (submission.isSubmitted) {
    return const _StatusStyle('Submitted', Color(0xFF1A7F4B), Color(0xFFEAFAF1));
  }
  if (submission.hasUpload) {
    return const _StatusStyle('Draft uploaded', Color(0xFFB87700), Color(0xFFFFF4E5));
  }
  return const _StatusStyle('Not started', AppColors.textMuted, AppColors.chipBackground);
}
