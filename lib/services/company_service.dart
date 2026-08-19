import '../core/api_client.dart';
import '../models/company_analytics.dart';
import '../models/company_application.dart';
import '../models/company_assessment.dart';
import '../models/company_placement.dart';
import '../models/company_profile.dart';
import '../models/review.dart';
import '../screens/company/company_posting.dart';

/// Talks to Api\CompanyProfileController and Api\CompanyPostingController,
/// which read and write the same `companies` and `internships` rows the
/// website's company pages use — postings go through the shared
/// CompanyPostingService on the backend, so a posting written here is stored
/// exactly as one written on the web.
class CompanyService {
  final ApiClient _client = ApiClient.instance;

  // ---- profile ----

  Future<CompanyProfile> fetchProfile() async {
    final response = await _client.get('/company/profile', authenticated: true);
    return CompanyProfile.fromJson(response['company'] as Map<String, dynamic>);
  }

  Future<CompanyProfile> updateProfile({
    required String companyName,
    String? industry,
    String? description,
    String? address,
    String? region,
    String? province,
    String? city,
    String? barangay,
    String? website,
    String? contactEmail,
    String? contactNumber,
  }) async {
    final response = await _client.put(
      '/company/profile',
      {
        'company_name': companyName,
        // Null means "not being edited here", so the entry is dropped rather
        // than sent as null and blanking a stored value.
        'industry': ?industry,
        'description': ?description,
        'address': ?address,
        'region': ?region,
        'province': ?province,
        'city': ?city,
        'barangay': ?barangay,
        'website': ?website,
        'contact_email': ?contactEmail,
        'contact_number': ?contactNumber,
      },
      authenticated: true,
    );

    return CompanyProfile.fromJson(response['company'] as Map<String, dynamic>);
  }

  /// Returns the new logo URL.
  Future<String?> updateLogo(String filePath) async {
    final response = await _client.postMultipart(
      '/company/profile/logo',
      fields: const {},
      filePath: filePath,
      fileFieldName: 'logo',
      authenticated: true,
    );

    return response['logo_url'] as String?;
  }

  /// The feedback shown on the company's own profile: reviews left on the
  /// company plus reviews left on any of its postings, exactly the merged
  /// list the web profile page renders (Company::allReviews()).
  Future<({List<Review> reviews, ReviewSummary summary})> fetchProfileReviews() async {
    final response = await _client.get('/company/profile/reviews', authenticated: true);

    return (
      reviews: (response['reviews'] as List? ?? const [])
          .map((e) => Review.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary: response['summary'] != null
          ? ReviewSummary.fromJson(response['summary'] as Map<String, dynamic>)
          : ReviewSummary.empty(),
    );
  }

  // ---- dashboard & analytics ----

  Future<CompanyDashboard> fetchDashboard() async {
    final response = await _client.get('/company/dashboard', authenticated: true);
    return CompanyDashboard.fromJson(response);
  }

  /// [internshipId] narrows the applicant pipeline to one posting, the same
  /// thing the web analytics page's dropdown does.
  Future<CompanyAnalytics> fetchAnalytics({int? internshipId}) async {
    final suffix = internshipId == null ? '' : '?internship_id=$internshipId';
    final response = await _client.get('/company/analytics$suffix', authenticated: true);
    return CompanyAnalytics.fromJson(response);
  }

  // ---- placements ----

  Future<({List<CompanyPlacement> placements, PlacementCounts counts})> fetchPlacements({
    String status = '',
    String query = '',
  }) async {
    final params = <String, String>{
      if (status.isNotEmpty) 'status': status,
      if (query.trim().isNotEmpty) 'q': query.trim(),
    };
    final suffix = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')}';

    final response = await _client.get('/company/placements$suffix', authenticated: true);

    return (
      placements: (response['placements'] as List? ?? const [])
          .map((e) => CompanyPlacement.fromJson(e as Map<String, dynamic>))
          .toList(),
      counts: PlacementCounts.fromJson(
        response['counts'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }

  Future<CompanyPlacementDetail> fetchPlacement(int id) async {
    final response = await _client.get('/company/placements/$id', authenticated: true);
    return CompanyPlacementDetail.fromJson(
      response['placement'] as Map<String, dynamic>,
    );
  }

  // ---- postings ----

  Future<List<CompanyPosting>> fetchPostings() async {
    final response = await _client.get('/company/postings', authenticated: true);
    return (response['postings'] as List? ?? const [])
        .map((e) => CompanyPosting.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CompanyPosting> createPosting({
    required String jobRole,
    required int slots,
    required List<String> responsibilities,
    required List<String> skills,
  }) async {
    final response = await _client.post(
      '/company/postings',
      {
        'job_role': jobRole,
        'slots': slots,
        'responsibilities': responsibilities,
        'skills': skills,
      },
      authenticated: true,
    );

    return CompanyPosting.fromJson(response['posting'] as Map<String, dynamic>);
  }

  Future<CompanyPosting> updatePosting({
    required int id,
    required String jobRole,
    required int slots,
    required List<String> responsibilities,
    required List<String> skills,
  }) async {
    final response = await _client.put(
      '/company/postings/$id',
      {
        'job_role': jobRole,
        'slots': slots,
        'responsibilities': responsibilities,
        'skills': skills,
      },
      authenticated: true,
    );

    return CompanyPosting.fromJson(response['posting'] as Map<String, dynamic>);
  }

  /// Flips a posting between open and closed, the same toggle the web has.
  Future<CompanyPosting> togglePostingStatus(int id) async {
    final response = await _client.post(
      '/company/postings/$id/toggle-status',
      const {},
      authenticated: true,
    );

    return CompanyPosting.fromJson(response['posting'] as Map<String, dynamic>);
  }

  Future<void> deletePosting(int id) async {
    await _client.delete('/company/postings/$id', authenticated: true);
  }

  // ---- applications ----

  Future<({List<CompanyApplication> applications, ApplicationCounts counts})> fetchApplications({
    String status = '',
    String query = '',
  }) async {
    final params = <String, String>{
      if (status.isNotEmpty) 'status': status,
      if (query.trim().isNotEmpty) 'q': query.trim(),
    };
    final suffix = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')}';

    final response = await _client.get('/company/applications$suffix', authenticated: true);

    return (
      applications: (response['applications'] as List? ?? const [])
          .map((e) => CompanyApplication.fromJson(e as Map<String, dynamic>))
          .toList(),
      counts: ApplicationCounts.fromJson(
        response['counts'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }

  Future<CompanyApplication> fetchApplication(int id) async {
    final response = await _client.get('/company/applications/$id', authenticated: true);
    return CompanyApplication.fromJson(response['application'] as Map<String, dynamic>);
  }

  /// Moves an application to [status]. A rejection may carry a reason, which
  /// the student sees — the same field the web form offers.
  Future<CompanyApplication> updateApplicationStatus({
    required int id,
    required String status,
    String? rejectionReason,
  }) async {
    final response = await _client.post(
      '/company/applications/$id/status',
      {'status': status, 'rejection_reason': ?rejectionReason},
      authenticated: true,
    );

    return CompanyApplication.fromJson(response['application'] as Map<String, dynamic>);
  }

  /// Reverts the most recent status change (one level, no redo).
  Future<CompanyApplication> undoApplicationStatus(int id) async {
    final response = await _client.post(
      '/company/applications/$id/undo-status',
      const {},
      authenticated: true,
    );

    return CompanyApplication.fromJson(response['application'] as Map<String, dynamic>);
  }

  /// The assessments this company can hand to an applicant — anything it has
  /// authored, matching the latitude the web's assign dialog gives.
  Future<List<CompanyAssessment>> fetchAssignableAssessments() async {
    final response = await _client.get(
      '/company/applications-assignable-assessments',
      authenticated: true,
    );

    return (response['assessments'] as List? ?? const [])
        .map((e) => CompanyAssessment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Hands [assessmentId] to the applicant, opening a fresh attempt window
  /// and notifying the student — the same shared service call the web's
  /// assign action makes.
  Future<CompanyApplication> assignAssessment({
    required int applicationId,
    required int assessmentId,
  }) async {
    final response = await _client.post(
      '/company/applications/$applicationId/assign-assessment',
      {'assessment_id': assessmentId},
      authenticated: true,
    );

    return CompanyApplication.fromJson(response['application'] as Map<String, dynamic>);
  }

  // ---- candidates ----

  Future<List<Candidate>> fetchCandidates({
    String query = '',
    String sort = 'match_score',
    int? minScore,
  }) async {
    final params = <String, String>{
      if (query.trim().isNotEmpty) 'q': query.trim(),
      'sort': sort,
      if (minScore != null) 'min_score': '$minScore',
    };
    final suffix = '?${params.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')}';

    final response = await _client.get('/company/candidates$suffix', authenticated: true);

    return (response['candidates'] as List? ?? const [])
        .map((e) => Candidate.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Candidate>> fetchBookmarkedCandidates() async {
    final response = await _client.get('/company/candidates/bookmarks', authenticated: true);
    return (response['candidates'] as List? ?? const [])
        .map((e) => Candidate.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Toggles: returns whether the candidate is bookmarked afterwards.
  Future<bool> toggleCandidateBookmark(int studentId) async {
    final response = await _client.post(
      '/company/candidates/$studentId/bookmark',
      const {},
      authenticated: true,
    );

    return response['bookmarked'] as bool? ?? false;
  }
}
