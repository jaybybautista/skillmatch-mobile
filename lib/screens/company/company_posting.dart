import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/json_parse.dart';

/// A single posting on the company side — shared by [CompanyHomeScreen]'s
/// "Active Postings" carousel and [CompanyPostingsScreen]'s full list.
///
/// Backed by GET /api/company/postings, which reads the same `internships`
/// rows (plus their responsibility and skill rows) the website's "My
/// Postings" page manages — so a posting created on either platform shows up
/// on the other.
class CompanyPosting {
  const CompanyPosting({
    required this.id,
    required this.title,
    required this.location,
    required this.applicants,
    required this.openSlots,
    this.slotsFilled = 0,
    this.status = 'open',
    this.description,
    this.responsibilities = const [],
    this.skills = const [],
    this.postedAtHuman,
  });

  final int id;
  final String title;
  final String location;
  final int applicants;
  final int openSlots;
  final int slotsFilled;
  final String status;
  final String? description;
  final List<String> responsibilities;
  final List<String> skills;
  final String? postedAtHuman;

  bool get isOpen => status == 'open';

  factory CompanyPosting.fromJson(Map<String, dynamic> json) {
    return CompanyPosting(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? 'Untitled posting',
      location: json['location'] as String? ?? '',
      applicants: (json['application_count'] as num?)?.toInt() ?? 0,
      openSlots: (json['slots_available'] as num?)?.toInt() ?? 0,
      slotsFilled: (json['slots_filled'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'open',
      description: json['description'] as String?,
      responsibilities: (json['responsibilities'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      skills: (json['skills'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      postedAtHuman: json['posted_at_human'] as String?,
    );
  }
}

/// The six application buckets behind a posting, as counted by
/// GET /api/company/postings/{id}.
///
/// The names are the web's (`hired`, `shortlisted`) rather than the database's
/// (`accepted`, `interview`) because both platforms read the same serialized
/// keys - renaming them here would only make the two disagree.
class PostingStatusCounts {
  const PostingStatusCounts({
    this.pending = 0,
    this.reviewing = 0,
    this.shortlisted = 0,
    this.hired = 0,
    this.rejected = 0,
    this.withdrawn = 0,
  });

  final int pending;
  final int reviewing;
  final int shortlisted;
  final int hired;
  final int rejected;
  final int withdrawn;

  factory PostingStatusCounts.fromJson(Map<String, dynamic> json) =>
      PostingStatusCounts(
        pending: asInt(json['pending']),
        reviewing: asInt(json['reviewing']),
        shortlisted: asInt(json['shortlisted']),
        hired: asInt(json['hired']),
        rejected: asInt(json['rejected']),
        withdrawn: asInt(json['withdrawn']),
      );
}

/// The "APPLICANTS" / "OPEN SLOTS" stat chip shown on a posting card -
/// shared by the home carousel card and the full "My Postings" list card.
class PostingStatTile extends StatelessWidget {
  const PostingStatTile({super.key, required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.chipBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value.toString().padLeft(2, '0'),
            style: AppFonts.title(fontSize: 18, color: AppColors.textDark),
          ),
        ],
      ),
    );
  }
}
