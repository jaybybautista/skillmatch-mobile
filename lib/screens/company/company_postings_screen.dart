import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/company_navigation.dart';
import '../../services/company_service.dart';
import '../../widgets/company_bottom_nav.dart';
import '../../widgets/company_screen_header.dart';
import '../../widgets/company_sidebar.dart';
import 'company_posting.dart';
import 'create_post_screen.dart';
import 'posting_applicants_screen.dart';

/// "My Postings" — the company's Internship tab. Lists everything posted so
/// far and links into [CreatePostScreen] for a new one.
///
/// Backed by GET /api/company/postings — the same `internships` rows the
/// website's "My Postings" page manages, so deleting or closing one here is
/// reflected there too.
class CompanyPostingsScreen extends StatefulWidget {
  const CompanyPostingsScreen({super.key, this.service});

  final CompanyService? service;

  @override
  State<CompanyPostingsScreen> createState() => _CompanyPostingsScreenState();
}

class _CompanyPostingsScreenState extends State<CompanyPostingsScreen> {
  late final CompanyService _service = widget.service ?? CompanyService();

  bool _isLoading = true;
  Object? _error;
  List<CompanyPosting> _postings = const [];

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
      final postings = await _service.fetchPostings();
      if (!mounted) return;
      setState(() {
        _postings = postings;
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

  Future<void> _createPost() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreatePostScreen()));
    // A posting may have been added while we were away.
    if (mounted) await _load();
  }

  void _openApplicants(CompanyPosting posting) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PostingApplicantsScreen(posting: posting)));
  }

  Future<void> _toggleStatus(CompanyPosting posting) async {
    try {
      final updated = await _service.togglePostingStatus(posting.id);
      _notify(updated.isOpen ? '"${updated.title}" reopened.' : '"${updated.title}" closed.');
      await _load();
    } on ApiException catch (e) {
      _notify(e.message);
    }
  }

  Future<void> _confirmDelete(CompanyPosting posting) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove posting?'),
        content: Text(
          posting.applicants > 0
              ? '"${posting.title}" has ${posting.applicants} '
                  '${posting.applicants == 1 ? 'applicant' : 'applicants'}. '
                  'Removing it also removes their applications.'
              : 'This removes "${posting.title}" for good.',
        ),
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
      await _service.deletePosting(posting.id);
      _notify('"${posting.title}" has been removed.');
      await _load();
    } on ApiException catch (e) {
      _notify(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const CompanySidebar(current: CompanySidebarItem.postings),
      backgroundColor: AppColors.primaryDark,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CompanyScreenHeader(title: 'My postings', showMenuButton: true),
          Expanded(
            child: ColoredBox(
              color: AppColors.background,
              child: RefreshIndicator(onRefresh: _load, child: _buildBody()),
            ),
          ),
        ],
      ),
      bottomNavigationBar: CompanyBottomNav(
        currentIndex: 1,
        onSelect: (i) => handleCompanyNavTap(context, i),
      ),
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
            _error is ApiException
                ? (_error as ApiException).message
                : 'Could not load your postings.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          Center(child: TextButton(onPressed: _load, child: const Text('Retry'))),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
      children: [
        _NewPostingBanner(onTap: _createPost),
        const SizedBox(height: 16),
        if (_postings.isEmpty)
          // Same wording the website's empty "My postings" page uses.
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 44, horizontal: 8),
            child: Column(
              children: [
                Icon(Icons.work_outline, size: 40, color: AppColors.textMuted),
                SizedBox(height: 14),
                Text(
                  'No internships posted yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Create your first posting to start receiving applications '
                  'from matched students.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, height: 1.4),
                ),
              ],
            ),
          )
        else
          for (var i = 0; i < _postings.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == _postings.length - 1 ? 0 : 16),
              child: _MyPostingCard(
                posting: _postings[i],
                onTap: () => _openApplicants(_postings[i]),
                onEdit: () => _toggleStatus(_postings[i]),
                onDelete: () => _confirmDelete(_postings[i]),
              ),
            ),
      ],
    );
  }
}

/// The "Post New Internship" call-to-action card atop the list.
class _NewPostingBanner extends StatelessWidget {
  const _NewPostingBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.chipBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Post New Internship', style: AppFonts.title(fontSize: 17, color: AppColors.primary)),
          const SizedBox(height: 2),
          const Text('Create a new opportunity', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Post'),
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          ),
        ],
      ),
    );
  }
}

/// A posting card with edit/delete actions — the full-list counterpart to
/// [CompanyHomeScreen]'s carousel `_PostingCard`.
/// "Open" / "Closed" pill, mirroring the status badge on the web posting card.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isOpen});

  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isOpen ? const Color(0xFFEAFAF1) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isOpen ? 'Open' : 'Closed',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          color: isOpen ? const Color(0xFF1A7F4B) : const Color(0xFF64748B),
        ),
      ),
    );
  }
}

class _MyPostingCard extends StatelessWidget {
  const _MyPostingCard({required this.posting, required this.onTap, required this.onEdit, required this.onDelete});

  final CompanyPosting posting;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(posting.title, style: AppFonts.title(fontSize: 17))),
                  const SizedBox(width: 8),
                  // Open/closed toggle, the same action the web card offers.
                  _IconAction(
                    icon: posting.isOpen ? Icons.pause_circle_outline : Icons.play_circle_outline,
                    onTap: onEdit,
                  ),
                  const SizedBox(width: 8),
                  _IconAction(icon: Icons.delete_outline, onTap: onDelete),
                ],
              ),
              const SizedBox(height: 8),
              _StatusBadge(isOpen: posting.isOpen),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      posting.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 13.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: PostingStatTile(label: 'APPLICANTS', value: posting.applicants)),
                  const SizedBox(width: 10),
                  Expanded(child: PostingStatTile(label: 'OPEN SLOTS', value: posting.openSlots)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 17, color: AppColors.textDark),
      ),
    );
  }
}






