import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillmatch/models/public_profile.dart';
import 'package:skillmatch/screens/student/profile/company_public_profile_screen.dart';
import 'package:skillmatch/screens/student/profile/coordinator_public_profile_screen.dart';
import 'package:skillmatch/screens/student/profile/profile_screen.dart';
import 'package:skillmatch/screens/student/profile/student_public_profile_screen.dart';
import 'package:skillmatch/services/public_profile_service.dart';

class _FakeProfileService extends PublicProfileService {
  _FakeProfileService({this.student, this.company, this.coordinator, this.error});

  final StudentPublicProfile? student;
  final CompanyPublicProfile? company;
  final CoordinatorPublicProfile? coordinator;
  final Object? error;

  @override
  Future<StudentPublicProfile> fetchStudent(int studentId) async {
    if (error != null) throw error!;
    return student!;
  }

  @override
  Future<CompanyPublicProfile> fetchCompany(int companyId) async {
    if (error != null) throw error!;
    return company!;
  }

  @override
  Future<CoordinatorPublicProfile> fetchCoordinator(int coordinatorId) async {
    if (error != null) throw error!;
    return coordinator!;
  }
}

/// Records the widget type of every route pushed as a replacement, without
/// needing that route's own async work (a real network fetch, here) to
/// finish — the assertion only cares that navigation happened.
class _RecordingNavigatorObserver extends NavigatorObserver {
  final replacedWith = <Type>[];

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final page = newRoute;
    if (page is MaterialPageRoute) {
      replacedWith.add(page.builder(page.navigator!.context).runtimeType);
    }
  }
}

void main() {
  group('models', () {
    test('StudentPublicProfile.isSelf short-circuits the rest of the payload', () {
      final profile = StudentPublicProfile.fromJson({'is_self': true});
      expect(profile.isSelf, isTrue);
      expect(profile.name, isNull);
    });

    test('StudentPublicProfile parses a full peer record', () {
      final profile = StudentPublicProfile.fromJson({
        'is_self': false,
        'name': 'Ana Cruz',
        'course': 'BSIT',
        'year_level': 3,
        'campus': 'Urdaneta City Campus',
        'skills': ['Laravel', 'Flutter'],
        'is_on_ojt': true,
        'placement_company': 'Creatix Studio',
        'education': [
          {'institution': 'PSU', 'degree': 'BSIT', 'field_of_study': null, 'start_year': 2022, 'end_year': null},
        ],
        'certifications': [],
        'experiences': [],
      });

      expect(profile.isSelf, isFalse);
      expect(profile.name, 'Ana Cruz');
      expect(profile.skills, ['Laravel', 'Flutter']);
      expect(profile.isOnOjt, isTrue);
      expect(profile.education.single.institution, 'PSU');
    });

    test('CompanyPublicProfile parses open internships', () {
      final profile = CompanyPublicProfile.fromJson({
        'id': 5,
        'name': 'Creatix Studio',
        'internship_count': 3,
        'open_internships': [
          {'id': 1, 'title': 'Product Design Intern', 'location': 'Manila', 'slots_available': 2, 'skills': ['Figma']},
        ],
      });

      expect(profile.internshipCount, 3);
      expect(profile.openInternships.single.title, 'Product Design Intern');
      expect(profile.openInternships.single.skills, ['Figma']);
    });

    test('CoordinatorPublicProfile.isSelf short-circuits the rest of the payload', () {
      final profile = CoordinatorPublicProfile.fromJson({'is_self': true});
      expect(profile.isSelf, isTrue);
      expect(profile.department, isNull);
    });
  });

  group('StudentPublicProfileScreen', () {
    testWidgets('renders skills, education, and the OJT badge', (tester) async {
      final service = _FakeProfileService(
        student: StudentPublicProfile.fromJson({
          'is_self': false,
          'name': 'Ana Cruz',
          'course': 'BSIT',
          'year_level': 3,
          'campus': 'Urdaneta City Campus',
          'skills': ['Laravel'],
          'is_on_ojt': true,
          'placement_company': 'Creatix Studio',
          'education': [
            {'institution': 'PSU', 'degree': 'BSIT', 'field_of_study': null, 'start_year': 2022, 'end_year': null},
          ],
          'certifications': [],
          'experiences': [],
        }),
      );

      await tester.pumpWidget(MaterialApp(
        home: StudentPublicProfileScreen(studentId: 1, service: service),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Ana Cruz'), findsOneWidget);
      expect(find.text('Laravel'), findsOneWidget);
      expect(find.text('PSU'), findsOneWidget);
      // Shown twice by design: the header's OJT chip, and the Overview
      // section's Status row further down the page.
      expect(find.text('On OJT at Creatix Studio'), findsOneWidget);
    });

    testWidgets('is_self triggers a pushReplacement to the editable profile screen', (tester) async {
      // ProfileScreen makes its own real network call in initState, so this
      // checks the navigation itself (via an observer) rather than pumping
      // ProfileScreen to settle — that would leave a dangling HTTP timer.
      final service = _FakeProfileService(student: StudentPublicProfile.fromJson({'is_self': true}));
      final observer = _RecordingNavigatorObserver();

      await tester.pumpWidget(MaterialApp(
        navigatorObservers: [observer],
        home: StudentPublicProfileScreen(studentId: 1, service: service),
      ));

      // Bounded pumps only — enough for the fake Future and the post-frame
      // callback that fires the redirect, never real wall-clock I/O.
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(observer.replacedWith, contains(ProfileScreen));
    });

    testWidgets('a load failure shows a retryable error', (tester) async {
      final service = _FakeProfileService(error: Exception('offline'));

      await tester.pumpWidget(MaterialApp(
        home: StudentPublicProfileScreen(studentId: 1, service: service),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('CompanyPublicProfileScreen', () {
    testWidgets('renders about, contact info, and open postings', (tester) async {
      final service = _FakeProfileService(
        company: CompanyPublicProfile.fromJson({
          'id': 5,
          'name': 'Creatix Studio',
          'industry': 'Design',
          'description': 'A design studio.',
          'contact_email': 'hr@creatix.test',
          'internship_count': 2,
          'open_internships': [
            {'id': 1, 'title': 'Product Design Intern', 'location': 'Manila', 'slots_available': 2, 'skills': []},
          ],
        }),
      );

      await tester.pumpWidget(MaterialApp(
        home: CompanyPublicProfileScreen(companyId: 5, service: service),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Creatix Studio'), findsWidgets);
      expect(find.text('A design studio.'), findsOneWidget);
      expect(find.text('hr@creatix.test'), findsOneWidget);
      expect(find.text('Product Design Intern'), findsOneWidget);

      // Below the fold in the test viewport — bring it into view first.
      await tester.scrollUntilVisible(find.text('Reviews & Feedback'), 300);
      expect(find.text('Reviews & Feedback'), findsOneWidget);
    });

    testWidgets('tapping Reviews & Feedback opens the company reviews screen', (tester) async {
      final service = _FakeProfileService(
        company: CompanyPublicProfile.fromJson({'id': 5, 'name': 'Creatix Studio'}),
      );

      await tester.pumpWidget(MaterialApp(
        home: CompanyPublicProfileScreen(companyId: 5, service: service),
      ));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Reviews & Feedback'), 300);
      await tester.tap(find.text('Reviews & Feedback'));
      // Bounded pumps, not pumpAndSettle: CompanyReviewsScreen's ReviewsSection
      // makes its own real network call in initState, which this test has no
      // need to wait out.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(CompanyReviewsScreen), findsOneWidget);
    });
  });

  group('CoordinatorPublicProfileScreen', () {
    testWidgets('renders department, campus, and contact info', (tester) async {
      final service = _FakeProfileService(
        coordinator: CoordinatorPublicProfile.fromJson({
          'is_self': false,
          'name': 'Mr. Santos',
          'department': 'OJT Office',
          'campus': 'Urdaneta City Campus',
          'email': 'santos@psu.edu.ph',
        }),
      );

      await tester.pumpWidget(MaterialApp(
        home: CoordinatorPublicProfileScreen(coordinatorId: 3, service: service),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Mr. Santos'), findsOneWidget);
      expect(find.text('OJT Office'), findsWidgets);
      expect(find.text('santos@psu.edu.ph'), findsOneWidget);
    });

    testWidgets('is_self triggers a pushReplacement to the editable profile screen', (tester) async {
      final service = _FakeProfileService(coordinator: CoordinatorPublicProfile.fromJson({'is_self': true}));
      final observer = _RecordingNavigatorObserver();

      await tester.pumpWidget(MaterialApp(
        navigatorObservers: [observer],
        home: CoordinatorPublicProfileScreen(coordinatorId: 3, service: service),
      ));

      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(observer.replacedWith, contains(ProfileScreen));
    });
  });
}
