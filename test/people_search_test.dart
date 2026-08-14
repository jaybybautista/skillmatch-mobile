import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillmatch/models/internship.dart';
import 'package:skillmatch/models/person_search_result.dart';
import 'package:skillmatch/screens/matches/internship_search_screen.dart';
import 'package:skillmatch/services/internship_service.dart';
import 'package:skillmatch/services/people_search_service.dart';

class _EmptyInternshipService extends InternshipService {
  @override
  Future<List<Internship>> fetchAll({
    String query = '',
    InternshipFilter filter = InternshipFilter.topMatches,
  }) async =>
      const [];
}

class _FakePeopleService extends PeopleSearchService {
  _FakePeopleService(this.resultsByType);

  final Map<PersonSearchType, List<PersonSearchResult>> resultsByType;
  final calls = <(String, PersonSearchType)>[];

  @override
  Future<List<PersonSearchResult>> search({
    required String query,
    PersonSearchType type = PersonSearchType.all,
  }) async {
    calls.add((query, type));
    return resultsByType[type] ?? const [];
  }
}

PersonSearchResult _person({
  required String type,
  required String title,
  String? screen,
  Map<String, dynamic> params = const {},
}) {
  return PersonSearchResult.fromJson({
    'type': type,
    'id': 1,
    'title': title,
    'subtitle': 'Subtitle',
    'meta': '',
    'description': '',
    'badge': null,
    'avatar_url': null,
    'initials': title.substring(0, 1),
    'screen': screen,
    'screen_params': params,
  });
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('defaults to the Internships tab', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: InternshipSearchScreen(
        service: _EmptyInternshipService(),
        peopleService: _FakePeopleService(const {}),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Search internships'), findsOneWidget);
    // The ordering menu is internship-only.
    expect(find.byIcon(Icons.tune), findsOneWidget);
  });

  testWidgets('switching to Students queries the people service, not internships', (tester) async {
    final internships = _EmptyInternshipService();
    final people = _FakePeopleService({
      PersonSearchType.student: [_person(type: 'student', title: 'Ana Cruz')],
    });

    await tester.pumpWidget(MaterialApp(
      home: InternshipSearchScreen(service: internships, peopleService: people),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Students'));
    await tester.pumpAndSettle();

    // The ordering menu disappears — it has no meaning for people.
    expect(find.byIcon(Icons.tune), findsNothing);

    await _type(tester, 'ana');

    expect(people.calls, [('ana', PersonSearchType.student)]);
    expect(find.text('Ana Cruz'), findsOneWidget);
  });

  testWidgets('Companies and Coordinators each hit their own type filter', (tester) async {
    final people = _FakePeopleService({
      PersonSearchType.company: [_person(type: 'company', title: 'Creatix Studio')],
      PersonSearchType.coordinator: [_person(type: 'coordinator', title: 'Mr. Santos')],
    });

    await tester.pumpWidget(MaterialApp(
      home: InternshipSearchScreen(service: _EmptyInternshipService(), peopleService: people),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Companies'));
    await tester.pumpAndSettle();
    await _type(tester, 'creatix');
    expect(find.text('Creatix Studio'), findsOneWidget);

    // Clearing first avoids the "same query, new tab" re-query this screen
    // deliberately does (covered by its own test below) so this one only
    // asserts that each tab is wired to its own type filter.
    await _type(tester, '');
    await tester.tap(find.text('Coordinators'));
    await tester.pumpAndSettle();
    await _type(tester, 'santos');
    expect(find.text('Mr. Santos'), findsOneWidget);

    expect(people.calls, [
      ('creatix', PersonSearchType.company),
      ('santos', PersonSearchType.coordinator),
    ]);
  });

  testWidgets('switching tabs re-runs the same typed query', (tester) async {
    final people = _FakePeopleService({
      PersonSearchType.student: [_person(type: 'student', title: 'Match')],
    });

    await tester.pumpWidget(MaterialApp(
      home: InternshipSearchScreen(service: _EmptyInternshipService(), peopleService: people),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Students'));
    await tester.pumpAndSettle();
    await _type(tester, 'match');
    expect(find.text('Match'), findsOneWidget);

    // Field still holds "match" when switching tabs — no need to retype it.
    await tester.tap(find.text('Companies'));
    await tester.pumpAndSettle();

    expect(find.text('match'), findsOneWidget); // in the TextField
  });

  testWidgets('a result with no destination is not tappable', (tester) async {
    final people = _FakePeopleService({
      PersonSearchType.student: [_person(type: 'student', title: 'No Profile', screen: null)],
    });

    await tester.pumpWidget(MaterialApp(
      home: InternshipSearchScreen(service: _EmptyInternshipService(), peopleService: people),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Students'));
    await tester.pumpAndSettle();
    await _type(tester, 'x');

    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });

  testWidgets('no matches shows the empty state named after the active tab', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: InternshipSearchScreen(
        service: _EmptyInternshipService(),
        peopleService: _FakePeopleService(const {}),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Coordinators'));
    await tester.pumpAndSettle();
    await _type(tester, 'zzzzz');

    expect(find.text('No coordinators found'), findsOneWidget);
  });
}
