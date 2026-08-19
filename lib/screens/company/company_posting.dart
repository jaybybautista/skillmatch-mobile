import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

/// A single posting on the company side — shared by [CompanyHomeScreen]'s
/// "Active Postings" carousel and [CompanyPostingsScreen]'s full list.
///
/// TODO: static placeholder data — there is no company-postings endpoint on
/// the backend yet (companies can't post internships until an admin approves
/// their account; see CompanySetupReviewScreen). Swap for a real fetch once
/// `Api\CompanyInternshipController` (or equivalent) exists.
class CompanyPosting {
  const CompanyPosting({
    required this.title,
    required this.location,
    required this.applicants,
    required this.openSlots,
  });

  final String title;
  final String location;
  final int applicants;
  final int openSlots;
}

const placeholderCompanyPostings = [
  CompanyPosting(
    title: 'Product Design Intern',
    location: 'California, USA',
    applicants: 8,
    openSlots: 8,
  ),
  CompanyPosting(
    title: 'Backend Engineering Intern',
    location: 'Cebu, Philippines',
    applicants: 5,
    openSlots: 3,
  ),
];

/// The "APPLICANTS" / "OPEN SLOTS" stat chip shown on a posting card —
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
