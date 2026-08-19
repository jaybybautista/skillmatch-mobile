import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:skillmatch/models/company_profile.dart';
import 'package:skillmatch/models/review.dart';
import 'package:skillmatch/screens/auth/auth_screen.dart';
import 'package:skillmatch/services/auth_service.dart';
import 'package:skillmatch/screens/company/company_posting.dart';
import 'package:skillmatch/screens/company/company_postings_screen.dart';
import 'package:skillmatch/screens/company/company_profile_screen.dart';
import 'package:skillmatch/services/company_service.dart';
import 'package:skillmatch/widgets/company_sidebar.dart';

class _FakeCompanyService extends CompanyService {
  _FakeCompanyService({this.postings = const [], this.error});

  List<CompanyPosting> postings;
  final Object? error;
  final calls = <String>[];

  List<Review> reviews = const [];
  ReviewSummary summary = ReviewSummary.empty();

  @override
  Future<List<CompanyPosting>> fetchPostings() async {
    calls.add('fetchPostings');
    if (error != null) throw error!;
    return postings;
  }

  @override
  Future<CompanyPosting> togglePostingStatus(int id) async {
    calls.add('toggle:$id');
    return _posting(id: id, status: 'closed');
  }

  @override
  Future<void> deletePosting(int id) async {
    calls.add('delete:$id');
  }

  @override
  Future<CompanyProfile> fetchProfile() async {
    calls.add('fetchProfile');
    if (error != null) throw error!;
    return profile ?? _profileFixture();
  }

  /// The profile screen loads its feedback alongside the profile itself, so
  /// the fake has to answer this too — otherwise the screen falls through to
  /// the real HTTP client and never finishes loading.
  @override
  Future<({List<Review> reviews, ReviewSummary summary})> fetchProfileReviews() async {
    calls.add('fetchProfileReviews');
    if (error != null) throw error!;
    return (reviews: reviews, summary: summary);
  }

  CompanyProfile? profile;
}

CompanyProfile _profileFixture({
  String name = 'Creatix Studio',
  String? description = 'We mentor interns on real work.',
  String? logoUrl,
  String status = 'approved',
}) {
  return CompanyProfile.fromJson({
    'id': 1,
    'company_name': name,
    'industry': 'Design',
    'description': description,
    'address': 'Cebu City',
    'contact_email': 'hr@creatix.test',
    'contact_number': '0917',
    'website': 'https://creatix.test',
    'logo_url': logoUrl,
    'verification_status': status,
    'is_verified': status == 'approved',
    'stats': {
      'internship_count': 3,
      'open_slots': 12,
      'applicant_count': 7,
      'placement_count': 2,
    },
  });
}

CompanyPosting _posting({
  int id = 1,
  String title = 'Backend Intern',
  int applicants = 0,
  String status = 'open',
}) {
  return CompanyPosting.fromJson({
    'id': id,
    'title': title,
    'status': status,
    'location': 'Cebu',
    'description': 'Do backend things',
    'slots_available': 4,
    'slots_filled': 1,
    'application_count': applicants,
    'responsibilities': ['Build APIs'],
    'skills': ['Laravel', 'PHP'],
    'posted_at_human': '2 days ago',
  });
}

void main() {
  group('CompanyPosting model', () {
    test('parses the API shape', () {
      final posting = _posting(applicants: 3);

      expect(posting.id, 1);
      expect(posting.title, 'Backend Intern');
      expect(posting.applicants, 3);
      expect(posting.openSlots, 4);
      expect(posting.slotsFilled, 1);
      expect(posting.skills, ['Laravel', 'PHP']);
      expect(posting.responsibilities, ['Build APIs']);
      expect(posting.isOpen, isTrue);
    });

    test('a closed posting reports isOpen false', () {
      expect(_posting(status: 'closed').isOpen, isFalse);
    });
  });

  group('CompanyProfile model', () {
    Map<String, dynamic> json({
      String? description = 'We build things',
      String? address = 'Cebu',
      String? contactNumber = '0917',
      String status = 'approved',
    }) {
      return {
        'id': 2,
        'company_name': 'Creatix Studio',
        'industry': 'Design',
        'description': description,
        'address': address,
        'contact_number': contactNumber,
        'verification_status': status,
        'is_verified': status == 'approved',
        'stats': {
          'internship_count': 3,
          'open_slots': 12,
          'applicant_count': 7,
          'placement_count': 1,
        },
      };
    }

    test('parses profile and stats', () {
      final profile = CompanyProfile.fromJson(json());

      expect(profile.companyName, 'Creatix Studio');
      expect(profile.isVerified, isTrue);
      expect(profile.stats.internshipCount, 3);
      expect(profile.stats.openSlots, 12);
      expect(profile.stats.applicantCount, 7);
    });

    test('setup is complete only when all three wizard fields are filled', () {
      expect(CompanyProfile.fromJson(json()).isSetupComplete, isTrue);
      expect(CompanyProfile.fromJson(json(description: null)).isSetupComplete, isFalse);
      expect(CompanyProfile.fromJson(json(address: '  ')).isSetupComplete, isFalse);
      expect(CompanyProfile.fromJson(json(contactNumber: null)).isSetupComplete, isFalse);
    });

    test('pending and rejected are distinguishable', () {
      expect(CompanyProfile.fromJson(json(status: 'pending')).isPending, isTrue);
      expect(CompanyProfile.fromJson(json(status: 'rejected')).isRejected, isTrue);
      expect(CompanyProfile.fromJson(json()).isPending, isFalse);
    });
  });

  group('CompanyPostingsScreen', () {
    testWidgets('lists postings fetched from the service', (tester) async {
      final service = _FakeCompanyService(postings: [
        _posting(id: 1, title: 'Backend Intern'),
        _posting(id: 2, title: 'Design Intern'),
      ]);

      await tester.pumpWidget(MaterialApp(home: CompanyPostingsScreen(service: service)));
      await tester.pumpAndSettle();

      expect(service.calls, contains('fetchPostings'));
      expect(find.text('Backend Intern'), findsOneWidget);
      expect(find.text('Design Intern'), findsOneWidget);
    });

    testWidgets('an empty list explains what to do next', (tester) async {
      final service = _FakeCompanyService(postings: const []);

      await tester.pumpWidget(MaterialApp(home: CompanyPostingsScreen(service: service)));
      await tester.pumpAndSettle();

      // Same wording as the website's empty "My postings" page.
      expect(find.text('No internships posted yet'), findsOneWidget);
      expect(find.textContaining('Create your first posting'), findsOneWidget);
    });

    testWidgets('a load failure is retryable', (tester) async {
      final service = _FakeCompanyService(error: Exception('offline'));

      await tester.pumpWidget(MaterialApp(home: CompanyPostingsScreen(service: service)));
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('deleting asks for confirmation first, and warns about applicants', (tester) async {
      final service = _FakeCompanyService(postings: [_posting(id: 9, applicants: 3)]);

      await tester.pumpWidget(MaterialApp(home: CompanyPostingsScreen(service: service)));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // Nothing deleted until confirmed.
      expect(service.calls, isNot(contains('delete:9')));
      expect(find.text('Remove posting?'), findsOneWidget);
      expect(find.textContaining('3 applicants'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(service.calls, contains('delete:9'));
    });

    testWidgets('cancelling the delete dialog leaves the posting alone', (tester) async {
      final service = _FakeCompanyService(postings: [_posting(id: 9)]);

      await tester.pumpWidget(MaterialApp(home: CompanyPostingsScreen(service: service)));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(service.calls, isNot(contains('delete:9')));
    });
  });

  group('CompanyProfileScreen', () {
    testWidgets('shows the signed-in company\'s real details', (tester) async {
      final service = _FakeCompanyService()..profile = _profileFixture();

      await tester.pumpWidget(MaterialApp(home: CompanyProfileScreen(service: service)));
      await tester.pumpAndSettle();

      expect(service.calls, contains('fetchProfile'));
      expect(find.text('Creatix Studio'), findsWidgets);
      expect(find.text('We mentor interns on real work.'), findsOneWidget);
      expect(find.text('hr@creatix.test'), findsOneWidget);
      expect(find.text('Cebu City'), findsOneWidget);
    });

    testWidgets('renders the At a Glance figures', (tester) async {
      final service = _FakeCompanyService()..profile = _profileFixture();

      await tester.pumpWidget(MaterialApp(home: CompanyProfileScreen(service: service)));
      await tester.pumpAndSettle();

      expect(find.text('POSTINGS'), findsOneWidget);
      expect(find.text('12'), findsOneWidget); // open slots
      expect(find.text('7'), findsOneWidget);  // applicants
    });

    testWidgets('an empty summary explains what to do instead of showing a blank', (tester) async {
      final service = _FakeCompanyService()..profile = _profileFixture(description: null);

      await tester.pumpWidget(MaterialApp(home: CompanyProfileScreen(service: service)));
      await tester.pumpAndSettle();

      expect(find.textContaining('No summary yet'), findsOneWidget);
    });

    testWidgets('an unverified company is told where it stands', (tester) async {
      final service = _FakeCompanyService()..profile = _profileFixture(status: 'pending');

      await tester.pumpWidget(MaterialApp(home: CompanyProfileScreen(service: service)));
      await tester.pumpAndSettle();

      expect(find.text('Pending verification'), findsOneWidget);
    });

    testWidgets('a load failure is retryable', (tester) async {
      final service = _FakeCompanyService(error: Exception('offline'));

      await tester.pumpWidget(MaterialApp(home: CompanyProfileScreen(service: service)));
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('CompanySidebar', () {
    testWidgets('lists the same entries as the web company sidebar, in order', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(drawer: CompanySidebar(), body: SizedBox()),
      ));

      tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
      await tester.pumpAndSettle();

      for (final label in [
        'Home',
        'Dashboard and analytics',
        'My postings',
        'Applications',
        'Assessments',
        'Browse candidates',
        'Bookmarks',
        'Placements',
        'Records and reports',
        'Notifications',
        'ACCOUNT',
        'Company profile',
        'Settings',
      ]) {
        // The list is taller than the test viewport, so later entries have to
        // be scrolled into existence before the finder can see them.
        await tester.scrollUntilVisible(find.text(label), 60);
        expect(find.text(label), findsOneWidget, reason: 'missing "$label"');
      }
    });

    testWidgets('a web-only entry explains itself instead of navigating', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(drawer: CompanySidebar(), body: SizedBox()),
      ));

      tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Records and reports'));
      await tester.pumpAndSettle();

      expect(find.textContaining('only on the SkillMatch website'), findsOneWidget);
    });

    testWidgets('offers a way to sign out', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AuthService(),
          child: const MaterialApp(
            home: Scaffold(drawer: CompanySidebar(), body: SizedBox()),
          ),
        ),
      );

      tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Log Out'), 60);
      expect(find.text('Log Out'), findsOneWidget);
    });

    testWidgets('signing out asks for confirmation first', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AuthService(),
          child: const MaterialApp(
            home: Scaffold(drawer: CompanySidebar(), body: SizedBox()),
          ),
        ),
      );

      tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Log Out'), 60);
      await tester.ensureVisible(find.text('Log Out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log Out'));
      await tester.pumpAndSettle();

      expect(find.text('Log out?'), findsOneWidget);

      // Backing out leaves the session alone — no logout call, and we stay put.
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Log out?'), findsNothing);
      expect(find.byType(AuthScreen), findsNothing);
    });
  });
}
