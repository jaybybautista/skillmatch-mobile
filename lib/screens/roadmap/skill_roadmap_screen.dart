import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/skill_roadmap.dart';
import '../../services/skill_roadmap_service.dart';

/// Skill Roadmap — GET /api/student/roadmap, the same market-wide skill
/// comparison and suggested plan the web's Skill Roadmap page computes
/// (Student\StudentRoadmapController via the shared SkillRoadmapService).
/// The web page is three plain bulleted lists; this one shows the same
/// suggestions with a progress summary and a demand badge per skill, since
/// the backend already computes that count and the web just never showed it.
class SkillRoadmapScreen extends StatefulWidget {
  const SkillRoadmapScreen({super.key, this.service});

  final SkillRoadmapService? service;

  @override
  State<SkillRoadmapScreen> createState() => _SkillRoadmapScreenState();
}

class _SkillRoadmapScreenState extends State<SkillRoadmapScreen> {
  late final SkillRoadmapService _service = widget.service ?? SkillRoadmapService();

  bool _isLoading = true;
  Object? _error;
  SkillRoadmap? _roadmap;

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
      final roadmap = await _service.fetch();
      if (!mounted) return;
      setState(() {
        _roadmap = roadmap;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 20, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Skill Roadmap',
                          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'What to learn next, based on what open postings are asking for',
                          style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                        ),
                      ],
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
              child: RefreshIndicator(onRefresh: _load, child: _buildBody()),
            ),
          ),
        ],
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
            _error is ApiException ? (_error as ApiException).message : 'Could not load your roadmap.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          Center(child: TextButton(onPressed: _load, child: const Text('Retry'))),
        ],
      );
    }

    final roadmap = _roadmap!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        _ProgressCard(roadmap: roadmap),
        const SizedBox(height: 16),
        _SkillsSection(
          icon: Icons.trending_up,
          title: 'Worth learning',
          hint: 'The most in-demand skills across open postings that aren\'t on your profile yet.',
          skills: roadmap.suggestedSkills,
          demand: roadmap.skillDemand,
          chipColor: AppColors.primary,
          chipBackground: AppColors.chipBackground,
        ),
        if (roadmap.possessedSkills.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SkillsSection(
            icon: Icons.check_circle_outline,
            title: 'Already on your profile',
            hint: 'These are in-demand too — and you\'ve got them covered.',
            skills: roadmap.possessedSkills,
            demand: roadmap.skillDemand,
            chipColor: const Color(0xFF1A7F4B),
            chipBackground: const Color(0xFFEAFAF1),
          ),
        ],
        const SizedBox(height: 20),
        const Text(
          'Suggested plan',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < roadmap.steps.length; i++) ...[
          _StepCard(index: i + 1, step: roadmap.steps[i]),
          if (i != roadmap.steps.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.roadmap});

  final SkillRoadmap roadmap;

  @override
  Widget build(BuildContext context) {
    final have = roadmap.possessedSkills.length;
    final total = roadmap.trendingSkills.length;
    final fraction = roadmap.masteryFraction.clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Where you stand',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            total == 0
                ? 'No open postings to compare against yet — check back soon.'
                : 'You already have $have of the top $total skills companies are asking for right now.',
            style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : fraction,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillsSection extends StatelessWidget {
  const _SkillsSection({
    required this.icon,
    required this.title,
    required this.hint,
    required this.skills,
    required this.demand,
    required this.chipColor,
    required this.chipBackground,
  });

  final IconData icon;
  final String title;
  final String hint;
  final List<String> skills;
  final Map<String, int> demand;
  final Color chipColor;
  final Color chipBackground;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            children: [
              Icon(icon, size: 18, color: chipColor),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
            ],
          ),
          const SizedBox(height: 4),
          Text(hint, style: const TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.35)),
          const SizedBox(height: 12),
          if (skills.isEmpty)
            const Text(
              'Nothing to show here right now.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted, fontStyle: FontStyle.italic),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final skill in skills)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(color: chipBackground, borderRadius: BorderRadius.circular(999)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(skill, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: chipColor)),
                        if (demand[skill] != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            '· ${demand[skill]} ${demand[skill] == 1 ? 'posting' : 'postings'}',
                            style: TextStyle(fontSize: 11, color: chipColor.withValues(alpha: 0.75)),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.index, required this.step});

  final int index;
  final RoadmapStep step;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.chipBackground, shape: BoxShape.circle),
            child: Text(
              '$index',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        step.title,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        step.timeframe,
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  step.description,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.4),
                ),
                if (step.suggestedSkills.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final skill in step.suggestedSkills)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.chipBackground,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            skill,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                          ),
                        ),
                    ],
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
