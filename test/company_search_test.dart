import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:skillmatch/models/app_user.dart';
import 'package:skillmatch/models/internship.dart';
import 'package:skillmatch/models/person_search_result.dart';
import 'package:skillmatch/screens/company/posting_detail_screen.dart';
import 'package:skillmatch/screens/student/internship/internship_detail_screen.dart';
import 'package:skillmatch/screens/student/matches/internship_search_screen.dart';
import 'package:skillmatch/services/auth_service.dart';
import 'package:skillmatch/services/internship_service.dart';
import 'package:skillmatch/services/people_search_service.dart';

class _FakeInternshipService extends InternshipService {
  _FakeInternshipService({this.results = const []});

  List<Internship> results;
  final calls = <String>[];

  @override
  Future<List<Internship>> fetchAll({
    String query = '',
    InternshipFilter filter = InternshipFilter.topMatches,
  }) async {
    calls.add('search:$query:${filter.name}');
    return results;
  }
}

class _FakePeopleSearchService extends PeopleSearchService {
  @override
  Future<List<PersonSearchResult>> search({
    required String query,
    PersonSearchType type = PersonSearchType.all,
  }) async => const [];
}

Internship _internship({
  int id = 5,
  String title = 'Laravel Developer',
  int? companyId = 1,
}) {
  return Internship.fromJson({
    'id': id,
    'title': title,
    'company_id': companyId,
    'company_name': 'SkillMatch',
    'company_logo_url': null,
    'location': 'Pozorrubio, Pangasinan',
    'slots_available': 10,
    'description': 'rafsa',
    'match_score': null,
    'skills': ['Laravel'],
    'is_bookmarked': false,
    'is_applied': false,
  });
}

AuthService _auth({required String role, int? companyId}) {
  return AuthService()
    ..currentUser = AppUser(
      id: 1,
      name: role == 'company' ? 'SkillMatch' : 'Jayby Bautista',
      email: 'someone@skillmatch.test',
      role: role,
      status: 'active',
      companyId: companyId,
    );
}

/// Records what gets pushed, so a test can inspect the destination without
/// mounting it — the pushed screens build their own real services, and a
/// widget test has no business reaching the network.
class _RouteRecorder extends NavigatorObserver {
  Route<dynamic>? lastPushed;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    lastPushed = route;
    super.didPush(route, previousRoute);
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required String role,
  int? companyId,
  List<Internship> results = const [],
  _FakeInternshipService? service,
  _RouteRecorder? observer,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthService>.value(
      value: _auth(role: role, companyId: companyId),
      child: MaterialApp(
        navigatorObservers: [?observer],
        home: InternshipSearchScreen(
          service: service ?? _FakeInternshipService(results: results),
          peopleService: _FakePeopleSearchService(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The widget the recorded route would build, without building it into the
/// tree.
Widget _destination(WidgetTester tester, _RouteRecorder observer) {
  final route = observer.lastPushed! as MaterialPageRoute;
  return route.builder(tester.element(find.byType(InternshipSearchScreen)));
}

/// Types a query and lets the 400ms debounce fire.
Future<void> _search(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField), query);
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a company can search and sees the same four scopes', (
    tester,
  ) async {
    await _pump(
      tester,
      role: 'company',
      companyId: 1,
      results: [_internship()],
    );

    // The web offers a company exactly these.
    expect(find.text('Internships'), findsOneWidget);
    expect(find.text('Students'), findsOneWidget);
    expect(find.text('Companies'), findsOneWidget);
    expect(find.text('Coordinators'), findsOneWidget);

    await _search(tester, 'skil');
    expect(find.text('Laravel Developer'), findsOneWidget);
  });

  testWidgets('a company tapping its own posting lands on the posting page', (
    tester,
  ) async {
    final observer = _RouteRecorder();
    await _pump(
      tester,
      role: 'company',
      companyId: 1,
      results: [_internship(companyId: 1)],
      observer: observer,
    );

    await _search(tester, 'laravel');
    await tester.tap(find.text('Laravel Developer'));

    expect(_destination(tester, observer), isA<PostingDetailScreen>());
  });

  testWidgets(
    "another company's posting opens read-only, with no way to apply",
    (tester) async {
      final observer = _RouteRecorder();
      await _pump(
        tester,
        role: 'company',
        companyId: 1,
        results: [_internship(companyId: 99)],
        observer: observer,
      );

      await _search(tester, 'laravel');
      await tester.tap(find.text('Laravel Developer'));

      final screen = _destination(tester, observer);
      expect(screen, isA<InternshipDetailScreen>());
      expect((screen as InternshipDetailScreen).canApply, isFalse);
    },
  );

  testWidgets('a student still gets the applyable posting screen', (
    tester,
  ) async {
    final observer = _RouteRecorder();
    await _pump(
      tester,
      role: 'student',
      results: [_internship()],
      observer: observer,
    );

    await _search(tester, 'laravel');
    await tester.tap(find.text('Laravel Developer'));

    final screen = _destination(tester, observer);
    expect(screen, isA<InternshipDetailScreen>());
    expect((screen as InternshipDetailScreen).canApply, isTrue);
  });

  testWidgets('the "Top Matches" ordering is student-only', (tester) async {
    await _pump(tester, role: 'company', companyId: 1);
    expect(
      find.byType(InternshipFilterButton),
      findsNothing,
      reason: 'a company has no skills to be matched against',
    );

    await _pump(tester, role: 'student');
    expect(find.byType(InternshipFilterButton), findsOneWidget);
  });
}
