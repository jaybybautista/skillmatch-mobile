/// One review left for the company — shown in the "Reviews & Feedback"
/// section of [CompanyProfileScreen].
///
/// TODO: static placeholder data — there is no company-reviews endpoint on
/// the backend yet (same caveat as the rest of the company side). The
/// student-facing equivalent (`lib/models/review.dart` + `ReviewsSection`)
/// expects a real `reviewableType`/`reviewableId` fetch and has no
/// "On Internship: X" tag, so this is a separate, simpler, display-only
/// model rather than a company-side reuse of that one.
class CompanyReview {
  const CompanyReview({
    required this.reviewerName,
    required this.rating,
    required this.timeAgo,
    required this.tag,
    required this.body,
  });

  final String reviewerName;
  final int rating;
  final String timeAgo;
  final String tag;
  final String body;

  String get initials {
    final parts = reviewerName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

/// The rating breakdown shown atop the review list.
class CompanyReviewSummary {
  const CompanyReviewSummary({
    required this.average,
    required this.total,
    required this.ratingCounts,
  });

  final double average;
  final int total;
  final Map<int, int> ratingCounts;
}

const placeholderReviewSummary = CompanyReviewSummary(
  average: 4.7,
  total: 23,
  ratingCounts: {5: 15, 4: 5, 3: 3, 2: 0, 1: 0},
);

const placeholderCompanyReviews = [
  CompanyReview(
    reviewerName: 'Cameron Williamson',
    rating: 3,
    timeAgo: '2 mins ago',
    tag: 'On Internship: Product Design Intern',
    body:
        'Good exposure to real product work, but feedback loops from my mentor were slow — I often waited days for a review before I could move a task forward.',
  ),
  CompanyReview(
    reviewerName: 'Priya Malhotra',
    rating: 5,
    timeAgo: '1 day ago',
    tag: 'On Internship: Backend Engineering Intern',
    body:
        'Genuinely one of the best internships I\'ve had — I shipped a real feature to production in my second week and the team treated me like a full engineer from day one.',
  ),
];
