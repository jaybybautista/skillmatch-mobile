import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../../../models/resume.dart';
import '../../../services/resume_service.dart';
import '../../../widgets/autosave_text_field.dart';

class AchievementsEditScreen extends StatefulWidget {
  const AchievementsEditScreen({super.key, required this.section});

  final ResumeSection section;

  @override
  State<AchievementsEditScreen> createState() => _AchievementsEditScreenState();
}

class _AchievementsEditScreenState extends State<AchievementsEditScreen> {
  final _service = ResumeService();
  late final List<ResumeAchievementEntry> _entries = List.of(widget.section.achievements);
  bool _isAdding = false;

  void _showError(Object e) {
    final message = e is ApiException ? e.message : 'Something went wrong. Please try again.';
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addEntry() async {
    setState(() => _isAdding = true);
    try {
      final entry = await _service.addAchievement(widget.section.id);
      if (mounted) setState(() => _entries.add(entry));
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _deleteEntry(ResumeAchievementEntry entry) async {
    try {
      await _service.deleteAchievement(entry.id);
      if (mounted) setState(() => _entries.removeWhere((e) => e.id == entry.id));
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _save(
    ResumeAchievementEntry entry, {
    String? title,
    String? category,
    String? location,
    String? dateText,
  }) async {
    try {
      await _service.updateAchievement(entry.id, title: title, category: category, location: location, dateText: dateText);
    } catch (e) {
      _showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Achievements', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          _isAdding
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                )
              : IconButton(icon: const Icon(Icons.add), onPressed: _addEntry),
        ],
      ),
      body: _entries.isEmpty
          ? const Center(
              child: Text('Tap + to add your first achievement.', style: TextStyle(color: AppColors.textMuted)),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                for (final entry in _entries) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      key: ValueKey(entry.id),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: InkWell(
                            onTap: () => _deleteEntry(entry),
                            child: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                          ),
                        ),
                        AutosaveTextField(
                          label: 'Achievement Title',
                          initialValue: entry.title,
                          onChanged: (v) => _save(entry, title: v),
                        ),
                        const SizedBox(height: 12),
                        AutosaveTextField(
                          label: 'Category',
                          initialValue: entry.category,
                          onChanged: (v) => _save(entry, category: v),
                        ),
                        const SizedBox(height: 12),
                        AutosaveTextField(
                          label: 'Company / Location',
                          initialValue: entry.location,
                          onChanged: (v) => _save(entry, location: v),
                        ),
                        const SizedBox(height: 12),
                        AutosaveTextField(
                          label: 'Date',
                          initialValue: entry.dateText,
                          onChanged: (v) => _save(entry, dateText: v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
    );
  }
}
