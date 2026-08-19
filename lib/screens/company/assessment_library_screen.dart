import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/company_navigation.dart';
import '../../widgets/company_bottom_nav.dart';
import '../../widgets/company_screen_header.dart';
import '../../widgets/empty_results.dart';
import 'assessment_submissions_screen.dart';
import 'company_assessment.dart';
import 'create_assessment_screen.dart';

/// The company's Assessment tab — lists every assessment created so far and
/// links into [CreateAssessmentScreen] for a new one.
///
/// TODO: static placeholder data, same caveat as [CompanyPostingsScreen] —
/// there is no company-assessments endpoint to fetch/delete against yet.
/// Deleting a card here only removes it from this screen's in-memory list.
class AssessmentLibraryScreen extends StatefulWidget {
  const AssessmentLibraryScreen({super.key});

  @override
  State<AssessmentLibraryScreen> createState() =>
      _AssessmentLibraryScreenState();
}

class _AssessmentLibraryScreenState extends State<AssessmentLibraryScreen> {
  final _assessments = List<CompanyAssessment>.of(
    placeholderCompanyAssessments,
  );

  void _comingSoon(String what) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$what is coming soon.')));
  }

  void _viewSubmissions(CompanyAssessment assessment) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AssessmentSubmissionsScreen(assessment: assessment),
      ),
    );
  }

  Future<void> _createAssessment() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CreateAssessmentScreen()));
  }

  void _delete(int index) {
    setState(() => _assessments.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CompanyScreenHeader(
            title: 'Assessment Library',
            trailing: IconButton(
              onPressed: _createAssessment,
              icon: const Icon(Icons.add, color: Colors.white, size: 26),
            ),
          ),
          Expanded(
            child: ColoredBox(
              color: AppColors.background,
              child: _assessments.isEmpty
                  ? const EmptyResults(
                      title: 'No assessments yet',
                      hint:
                          'Tap the + button above to create your first assessment.',
                      icon: Icons.quiz_outlined,
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
                      children: [
                        for (var i = 0; i < _assessments.length; i++)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: i == _assessments.length - 1 ? 0 : 16,
                            ),
                            child: _AssessmentCard(
                              assessment: _assessments[i],
                              onEdit: () =>
                                  _comingSoon('Editing an assessment'),
                              onDelete: () => _delete(i),
                              onViewSubmissions: () =>
                                  _viewSubmissions(_assessments[i]),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: CompanyBottomNav(
        currentIndex: 2,
        onSelect: (i) => handleCompanyNavTap(context, i),
      ),
    );
  }
}

class _AssessmentCard extends StatelessWidget {
  const _AssessmentCard({
    required this.assessment,
    required this.onEdit,
    required this.onDelete,
    required this.onViewSubmissions,
  });

  final CompanyAssessment assessment;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onViewSubmissions;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  assessment.title,
                  style: AppFonts.title(fontSize: 17),
                ),
              ),
              const SizedBox(width: 8),
              _IconAction(icon: Icons.edit_outlined, onTap: onEdit),
              const SizedBox(width: 8),
              _IconAction(icon: Icons.delete_outline, onTap: onDelete),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            assessment.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.quiz_outlined,
                size: 17,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                '${assessment.questionCount} Questions',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 16),
              const Icon(
                Icons.access_time_rounded,
                size: 17,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                '${assessment.timeLimitMinutes} Mins',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: onViewSubmissions,
                child: const Text(
                  'View Submissions',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
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
