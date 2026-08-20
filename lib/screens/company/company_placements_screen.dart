import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/company_navigation.dart';
import '../../models/company_placement.dart';
import '../../services/company_service.dart';
import '../../widgets/matcha_launcher.dart';
import '../../widgets/company_bottom_nav.dart';
import '../../widgets/company_screen_header.dart';
import '../../widgets/company_sidebar.dart';
import 'placement_detail_screen.dart';

/// The status filters the web placements page offers, in the same order.
const _statusFilters = <({String key, String label})>[
  (key: '', label: 'All'),
  (key: 'ongoing', label: 'Ongoing'),
  (key: 'completed', label: 'Completed'),
  (key: 'terminated', label: 'Terminated'),
];

/// Placements — the students doing (or who have done) their OJT with this
/// company. Backed by /api/company/placements, the same `placements` rows the
/// website lists, filtered by the same shared service.
///
/// Read-only, exactly like the web page: placements are created and updated
/// by coordinators, and a company only ever looks at them.
class CompanyPlacementsScreen extends StatefulWidget {
  const CompanyPlacementsScreen({super.key, this.service});

  final CompanyService? service;

  @override
  State<CompanyPlacementsScreen> createState() =>
      _CompanyPlacementsScreenState();
}

class _CompanyPlacementsScreenState extends State<CompanyPlacementsScreen> {
  late final CompanyService _service = widget.service ?? CompanyService();
  final _searchController = TextEditingController();
  Timer? _debounce;

  bool _isLoading = true;
  Object? _error;
  List<CompanyPlacement> _placements = const [];
  PlacementCounts _counts = PlacementCounts.empty;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _service.fetchPlacements(
        status: _status,
        query: _searchController.text,
      );
      if (!mounted) return;
      setState(() {
        _placements = result.placements;
        _counts = result.counts;
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

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  int _countFor(String key) => switch (key) {
    'ongoing' => _counts.ongoing,
    'completed' => _counts.completed,
    'terminated' => _counts.terminated,
    _ => _counts.total,
  };

  void _openDetail(CompanyPlacement placement) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlacementDetailScreen(
          placementId: placement.id,
          initialName: placement.studentName,
          service: widget.service,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Every top-level company screen carries the bar, so navigation
      // doesn't change shape depending on how you arrived. This screen is
      // not one of its four tabs, hence no highlight.
      bottomNavigationBar: CompanyBottomNav(
        currentIndex: -1,
        onSelect: (i) => handleCompanyNavTap(context, i),
      ),
      drawer: const CompanySidebar(current: CompanySidebarItem.placements),
      backgroundColor: AppColors.primaryDark,
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CompanyScreenHeader(
                title: 'Placements',
                showMenuButton: true,
              ),
              Expanded(
                child: ColoredBox(
                  color: AppColors.background,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          decoration: const InputDecoration(
                            hintText: 'Search by student name or email...',
                            prefixIcon: Icon(
                              Icons.search,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 44,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          children: [
                            for (final filter in _statusFilters)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(
                                    '${filter.label} (${_countFor(filter.key)})',
                                  ),
                                  selected: _status == filter.key,
                                  onSelected: (_) {
                                    setState(() => _status = filter.key);
                                    _load();
                                  },
                                  labelStyle: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: _status == filter.key
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: _status == filter.key
                                        ? Colors.white
                                        : AppColors.textDark,
                                  ),
                                  selectedColor: AppColors.primary,
                                  backgroundColor: Colors.white,
                                  showCheckmark: false,
                                  side: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _load,
                          child: _buildBody(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Same launcher the web keeps on every page.
          const MatchaLauncher(),
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
            _error is ApiException
                ? (_error as ApiException).message
                : 'Could not load your placements.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(onPressed: _load, child: const Text('Retry')),
          ),
        ],
      );
    }

    if (_placements.isEmpty) {
      final isFiltered =
          _status.isNotEmpty || _searchController.text.trim().isNotEmpty;

      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 60, 32, 0),
            child: Column(
              children: [
                const Icon(
                  Icons.how_to_reg_outlined,
                  size: 40,
                  color: AppColors.textMuted,
                ),
                const SizedBox(height: 14),
                const Text(
                  'No placements found',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isFiltered
                      ? 'No placements match your current filters.'
                      // The same sentence the web page's empty state uses, so
                      // a company gets the same explanation on both.
                      : 'Accepted students will appear here once a coordinator '
                            'creates their placement record.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _placements.length,
      itemBuilder: (_, index) => _PlacementCard(
        placement: _placements[index],
        onTap: () => _openDetail(_placements[index]),
      ),
    );
  }
}

class _PlacementCard extends StatelessWidget {
  const _PlacementCard({required this.placement, required this.onTap});

  final CompanyPlacement placement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = placementStatusColors(placement.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Avatar(placement: placement),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            placement.studentName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          if (placement.studentEmail != null)
                            Text(
                              placement.studentEmail!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.background,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        placement.statusLabel,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: colors.text,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.work_outline,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        placement.internshipTitle ?? 'No posting on record',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.event_outlined,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${placement.startDate ?? 'No start date'}'
                      ' → ${placement.endDate ?? 'ongoing'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.placement});

  final CompanyPlacement placement;

  @override
  Widget build(BuildContext context) {
    final url = placement.studentAvatarUrl;

    return Container(
      width: 40,
      height: 40,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.chipBackground,
      ),
      child: url != null && url.isNotEmpty
          ? Image.network(
              url,
              fit: BoxFit.cover,
              width: 40,
              height: 40,
              // A broken avatar URL should not leave a grey hole in the row.
              errorBuilder: (_, _, _) => _initials(),
            )
          : _initials(),
    );
  }

  Widget _initials() => Text(
    placement.initials,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.bold,
      color: AppColors.primary,
    ),
  );
}
