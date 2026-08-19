import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../../../models/placement.dart';
import '../../../services/placement_service.dart';
import '../../../widgets/status_badge.dart';
import '../matches/matches_list_screen.dart';

/// My Placement — GET /api/student/placement, backed by the same
/// `placements` row the web app's My Placement page reads, including the
/// same OJT hours tracker math and the same Log Hours action.
class PlacementScreen extends StatefulWidget {
  const PlacementScreen({super.key});

  @override
  State<PlacementScreen> createState() => _PlacementScreenState();
}

class _PlacementScreenState extends State<PlacementScreen> {
  final _service = PlacementService();

  bool _isLoading = true;
  Object? _error;
  PlacementSummary? _summary;

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
      final summary = await _service.fetchPlacement();
      if (!mounted) return;
      setState(() {
        _summary = summary;
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Placement',
                          style: AppFonts.title(fontSize: 24, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Track your OJT progress, rendered hours, and coordinator details',
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
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      final message = _error is ApiException ? (_error as ApiException).message : 'Could not load your placement.';
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
        children: [
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 12),
          Center(child: TextButton(onPressed: _load, child: const Text('Retry'))),
        ],
      );
    }

    final summary = _summary!;
    final placement = summary.placement;

    if (placement == null) return _NoPlacementCard();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        _HeroCard(placement: placement, summary: summary),
        if (placement.canLogHours) ...[
          const SizedBox(height: 16),
          _LogHoursCard(onLogged: _applyLogged),
        ],
        const SizedBox(height: 16),
        _InfoPanel(
          icon: Icons.calendar_today_outlined,
          title: 'Placement Timeline',
          rows: [
            ('Start Date', placement.startDate ?? 'Not set'),
            ('Target Completion', placement.endDate ?? 'Not set'),
            ('Location', placement.location ?? 'On-site'),
          ],
        ),
        const SizedBox(height: 16),
        _InfoPanel(
          icon: Icons.person_outline,
          title: 'Supervising Coordinator',
          rows: [
            ('Coordinator', placement.coordinatorName),
            ('Email', placement.coordinatorEmail ?? '—'),
            ('Department', placement.coordinatorDept ?? 'OJT Department'),
          ],
        ),
        if (placement.remarks != null && placement.remarks!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _RemarksPanel(remarks: placement.remarks!),
        ],
      ],
    );
  }

  void _applyLogged(int hoursRendered, int progressPercent, int hoursRemaining) {
    final current = _summary;
    if (current == null) return;
    setState(() {
      _summary = PlacementSummary(
        placement: current.placement,
        requiredHours: current.requiredHours,
        hoursRendered: hoursRendered,
        progressPercent: progressPercent,
        hoursRemaining: hoursRemaining,
      );
    });
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.placement, required this.summary});

  final Placement placement;
  final PlacementSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
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
              _CompanyLogo(logoUrl: placement.companyLogoUrl, initial: placement.companyInitial),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      placement.roleTitle,
                      style: AppFonts.title(fontSize: 17),
                    ),
                    const SizedBox(height: 2),
                    Text(placement.companyName, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(status: placement.status, compact: true),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'OJT Hours Rendered',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                    ),
                    Text(
                      '${summary.hoursRendered} / ${summary.requiredHours} hrs',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: summary.progressPercent / 100,
                    minHeight: 10,
                    backgroundColor: AppColors.border,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${summary.progressPercent}% Completed',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    Text(
                      '${summary.hoursRemaining} Hours Remaining',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LogHoursCard extends StatefulWidget {
  const _LogHoursCard({required this.onLogged});

  final void Function(int hoursRendered, int progressPercent, int hoursRemaining) onLogged;

  @override
  State<_LogHoursCard> createState() => _LogHoursCardState();
}

class _LogHoursCardState extends State<_LogHoursCard> {
  final _service = PlacementService();
  final _hoursController = TextEditingController();
  final _remarksController = TextEditingController();
  bool _isSaving = false;
  String? _hoursError;

  @override
  void dispose() {
    _hoursController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final hours = double.tryParse(_hoursController.text.trim());

    // Same bounds the web form and the API both enforce.
    if (hours == null || hours < 0.5 || hours > 24) {
      setState(() => _hoursError = 'Enter between 0.5 and 24 hours.');
      return;
    }

    setState(() {
      _hoursError = null;
      _isSaving = true;
    });

    try {
      final result = await _service.logHours(hours: hours, remarks: _remarksController.text);
      if (!mounted) return;
      widget.onLogged(result.hoursRendered, result.progressPercent, result.hoursRemaining);
      _hoursController.clear();
      _remarksController.clear();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not log your hours. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
            children: [
              const Icon(Icons.schedule_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Log Daily Work Hours', style: AppFonts.title(fontSize: 15)),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'HOURS WORKED',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 0.4),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _hoursController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: 'e.g. 8',
              isDense: true,
              errorText: _hoursError,
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'WORK TASK / REMARKS',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 0.4),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _remarksController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'e.g. Completed frontend UI integration task',
              isDense: true,
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _submit,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Log Hours'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.icon, required this.title, required this.rows});

  final IconData icon;
  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title, style: AppFonts.title(fontSize: 15)),
            ],
          ),
          const SizedBox(height: 6),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(row.$1, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                  ),
                  Expanded(
                    flex: 6,
                    child: Text(
                      row.$2,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
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

class _RemarksPanel extends StatelessWidget {
  const _RemarksPanel({required this.remarks});

  final String remarks;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            children: [
              const Icon(Icons.edit_note, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Latest Supervisor Remarks', style: AppFonts.title(fontSize: 15)),
            ],
          ),
          const SizedBox(height: 10),
          Text(remarks, style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textDark)),
        ],
      ),
    );
  }
}

class _NoPlacementCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(color: AppColors.chipBackground, shape: BoxShape.circle),
                child: const Icon(Icons.groups_outlined, size: 32, color: AppColors.primary),
              ),
              const SizedBox(height: 18),
              Text(
                'No Active Placement Recorded',
                textAlign: TextAlign.center,
                style: AppFonts.title(fontSize: 17),
              ),
              const SizedBox(height: 10),
              const Text(
                'Once a company accepts your application and your OJT placement is confirmed by your academic '
                'coordinator, your placement details and hours tracker will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.6),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MatchesListScreen()),
                  ),
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: const Text('Browse Internships'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Applications are coming soon.')),
                  ),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: const Text('View Applications'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompanyLogo extends StatelessWidget {
  const _CompanyLogo({required this.logoUrl, required this.initial});

  final String? logoUrl;
  final String initial;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: logoUrl != null
            ? Image.network(
                logoUrl!,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() => Text(
        initial,
        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 20),
      );
}
