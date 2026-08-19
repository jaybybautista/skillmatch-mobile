import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/company_navigation.dart';
import '../../widgets/company_bottom_nav.dart';
import '../../widgets/company_screen_header.dart';
import 'company_posting.dart';
import 'create_post_screen.dart';
import 'posting_applicants_screen.dart';

/// "My Postings" — the company's Internship tab. Lists everything posted so
/// far and links into [CreatePostScreen] for a new one.
///
/// TODO: static placeholder data, same caveat as [CompanyHomeScreen] — there
/// is no company-postings endpoint to fetch/delete against yet. Deleting a
/// card here only removes it from this screen's in-memory list, not any
/// backend.
class CompanyPostingsScreen extends StatefulWidget {
  const CompanyPostingsScreen({super.key});

  @override
  State<CompanyPostingsScreen> createState() => _CompanyPostingsScreenState();
}

class _CompanyPostingsScreenState extends State<CompanyPostingsScreen> {
  final _postings = List<CompanyPosting>.of(placeholderCompanyPostings);

  void _comingSoon(String what) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$what is coming soon.')));
  }

  Future<void> _createPost() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreatePostScreen()));
  }

  void _openApplicants(CompanyPosting posting) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PostingApplicantsScreen(posting: posting)));
  }

  void _delete(int index) {
    setState(() => _postings.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CompanyScreenHeader(title: 'My Postings'),
          Expanded(
            child: ColoredBox(
              color: AppColors.background,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
                children: [
                  _NewPostingBanner(onTap: _createPost),
                  const SizedBox(height: 16),
                  for (var i = 0; i < _postings.length; i++)
                    Padding(
                      padding: EdgeInsets.only(bottom: i == _postings.length - 1 ? 0 : 16),
                      child: _MyPostingCard(
                        posting: _postings[i],
                        onTap: () => _openApplicants(_postings[i]),
                        onEdit: () => _comingSoon('Editing a posting'),
                        onDelete: () => _delete(i),
                      ),
                    ),
                ],
              ),
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
                  _IconAction(icon: Icons.edit_outlined, onTap: onEdit),
                  const SizedBox(width: 8),
                  _IconAction(icon: Icons.delete_outline, onTap: onDelete),
                ],
              ),
              const SizedBox(height: 6),
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






