import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/profile_setup.dart';
import '../../services/profile_setup_service.dart';
import '../home/home_screen.dart';

/// The last stop: everything the wizard collected, read back from the server
/// so the student confirms what was actually saved rather than what was typed.
///
/// "Save and Continue" marks setup complete and recomputes match scores, so
/// Home already has recommendations when they arrive.
class SetupReviewScreen extends StatefulWidget {
  const SetupReviewScreen({super.key, this.service});

  final ProfileSetupService? service;

  @override
  State<SetupReviewScreen> createState() => _SetupReviewScreenState();
}

class _SetupReviewScreenState extends State<SetupReviewScreen> {
  late final ProfileSetupService _service = widget.service ?? ProfileSetupService();

  bool _isLoading = true;
  bool _isSaving = false;
  Object? _error;
  SetupReview? _review;

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
      final review = await _service.fetchReview();
      if (!mounted) return;
      setState(() {
        _review = review;
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

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      await _service.finish();
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      final message = e is ApiException ? e.message : 'Could not save your profile.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.primary,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 18),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    ),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Review your profile',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Check the details before saving.',
                            style: TextStyle(color: Colors.white70, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildError()
                    : _buildReview(_review!),
          ),
          if (!_isLoading && _error == null)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : const Text('Save and Continue'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildError() {
    final message = _error is ApiException
        ? (_error as ApiException).message
        : 'Could not load your profile.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildReview(SetupReview review) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
      children: [
        _Section(
          title: 'Personal Information',
          onEdit: () => Navigator.of(context).maybePop(),
          rows: [
            ('Name', review.personal.name),
            ('Email', review.personal.email),
            ('Phone', review.personal.phoneNumber),
            ('Address', review.personal.address),
          ],
        ),
        _Section(
          title: 'Education',
          onEdit: () => Navigator.of(context).maybePop(),
          rows: [
            ('School', review.school),
            ('Program', review.degree),
            ('Major', review.major),
          ],
        ),
        _SkillsSection(skills: review.skills, onEdit: () => Navigator.of(context).maybePop()),
        if (review.certifications.isNotEmpty)
          _ListSection(
            title: 'Certifications',
            onEdit: () => Navigator.of(context).maybePop(),
            entries: [
              for (final certification in review.certifications)
                (certification.title, certification.subtitle),
            ],
          ),
        if (review.experiences.isNotEmpty)
          _ListSection(
            title: 'Experience',
            onEdit: () => Navigator.of(context).maybePop(),
            entries: [
              for (final experience in review.experiences)
                (
                  experience.position,
                  [experience.organization, experience.period].where((s) => s.isNotEmpty).join(' • '),
                ),
            ],
          ),
        if (review.resumeName != null)
          _Card(
            title: 'Resume',
            onEdit: () => Navigator.of(context).maybePop(),
            child: Row(
              children: [
                const Icon(Icons.picture_as_pdf, color: Color(0xFFE03E3E)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    review.resumeName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, color: AppColors.textDark),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.onEdit, required this.child});

  final String title;
  final VoidCallback onEdit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              InkWell(
                onTap: onEdit,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.onEdit, required this.rows});

  final String title;
  final VoidCallback onEdit;
  final List<(String, String?)> rows;

  @override
  Widget build(BuildContext context) {
    final present = rows.where((r) => (r.$2 ?? '').trim().isNotEmpty).toList();

    return _Card(
      title: title,
      onEdit: onEdit,
      child: present.isEmpty
          ? const Text('Not provided', style: TextStyle(fontSize: 13, color: AppColors.textMuted))
          : Column(
              children: [
                for (final row in present)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 96,
                          child: Text(
                            row.$1,
                            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            row.$2!,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
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

class _SkillsSection extends StatelessWidget {
  const _SkillsSection({required this.skills, required this.onEdit});

  final List<String> skills;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Skills',
      onEdit: onEdit,
      child: skills.isEmpty
          ? const Text('None added', style: TextStyle(fontSize: 13, color: AppColors.textMuted))
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final skill in skills)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCE7F7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      skill,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ListSection extends StatelessWidget {
  const _ListSection({required this.title, required this.onEdit, required this.entries});

  final String title;
  final VoidCallback onEdit;
  final List<(String, String)> entries;

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: title,
      onEdit: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.$1,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  if (entry.$2.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      entry.$2,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
