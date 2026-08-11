import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillmatch/models/internship.dart';
import 'package:skillmatch/screens/matches/internship_search_screen.dart';
import 'package:skillmatch/services/internship_service.dart';

class _FakeInternshipService extends InternshipService {
  _FakeInternshipService(this.resultsByQuery);

  final Map<String, List<Internship>> resultsByQuery;
  final queries = <String>[];
  final filters = <InternshipFilter>[];

  @override
  Future<List<Internship>> fetchAll({
    String query = '',
    InternshipFilter filter = InternshipFilter.topMatches,
  }) async {
    queries.add(query);
    filters.add(filter);
    return resultsByQuery[query] ?? const [];
  }
}

Internship _internship(String title) => Internship.fromJson({
      'id': 1,
      'title': title,
      'company_name': 'Creatix Studio',
      'location': 'Manila',
    });

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  // Clear the 400ms debounce, then let the response land.
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('starts with a prompt and no results list', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: InternshipSearchScreen(service: _FakeInternshipService(const {})),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Search internships'), findsOneWidget);
    expect(find.text('No internships found'), findsNothing);
  });

  testWidgets('a query with no matches shows the empty state', (tester) async {
    final service = _FakeInternshipService(const {});

    await tester.pumpWidget(MaterialApp(home: InternshipSearchScreen(service: service)));
    await tester.pumpAndSettle();

    await _type(tester, 'zzzzz');

    expect(find.text('No internships found'), findsOneWidget);
    expect(find.text('Try a different keyword.'), findsOneWidget);
    expect(service.queries, ['zzzzz']);
  });

  testWidgets('matches render as cards with a result count', (tester) async {
    final service = _FakeInternshipService({
      'design': [_internship('Product Design Intern')],
    });

    await tester.pumpWidget(MaterialApp(home: InternshipSearchScreen(service: service)));
    await tester.pumpAndSettle();

    await _type(tester, 'design');

    expect(find.text('No internships found'), findsNothing);
    // The active ordering is named alongside the count.
    expect(find.text('1 result for "design" · Top Matches'), findsOneWidget);
    expect(find.text('Product Design Intern'), findsOneWidget);
  });

  group('filters', () {
    /// The orderings live behind the top-bar button, not in a chip row.
    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();
    }

    testWidgets('the dropdown offers the three orderings, defaulting to Top Matches',
        (tester) async {
      final service = _FakeInternshipService(const {});

      await tester.pumpWidget(MaterialApp(home: InternshipSearchScreen(service: service)));
      await tester.pumpAndSettle();

      // Nothing is on screen until the button is tapped.
      expect(find.text('Proximity Based'), findsNothing);

      await openMenu(tester);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Top Matches'), findsOneWidget);
      expect(find.text('Proximity Based'), findsOneWidget);

      await tester.tapAt(const Offset(10, 10)); // dismiss
      await tester.pumpAndSettle();

      await _type(tester, 'design');
      expect(service.filters.last, InternshipFilter.topMatches);
    });

    testWidgets('picking a filter re-queries with it', (tester) async {
      final service = _FakeInternshipService(const {});

      await tester.pumpWidget(MaterialApp(home: InternshipSearchScreen(service: service)));
      await tester.pumpAndSettle();

      await _type(tester, 'design');

      await openMenu(tester);
      await tester.tap(find.text('Proximity Based'));
      await tester.pumpAndSettle();
      await tester.pump();

      expect(service.filters.last, InternshipFilter.proximity);
      // The same query is re-run rather than cleared.
      expect(service.queries.last, 'design');
    });

    testWidgets('does not query on a filter change with an empty field', (tester) async {
      final service = _FakeInternshipService(const {});

      await tester.pumpWidget(MaterialApp(home: InternshipSearchScreen(service: service)));
      await tester.pumpAndSettle();

      await openMenu(tester);
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();

      expect(service.queries, isEmpty);
    });

    testWidgets('shows the distance the proximity ordering is based on', (tester) async {
      final service = _FakeInternshipService({
        'design': [
          Internship.fromJson({
            'id': 1,
            'title': 'Product Design Intern',
            'company_name': 'Creatix Studio',
            'distance_km': 12.4,
            'distance_formatted': '12.4 km away',
          }),
        ],
      });

      await tester.pumpWidget(MaterialApp(home: InternshipSearchScreen(service: service)));
      await tester.pumpAndSettle();

      await _type(tester, 'design');

      expect(find.text('12.4 km away'), findsOneWidget);
    });
  });

  testWidgets('clearing the field returns to the prompt', (tester) async {
    final service = _FakeInternshipService(const {});

    await tester.pumpWidget(MaterialApp(home: InternshipSearchScreen(service: service)));
    await tester.pumpAndSettle();

    await _type(tester, 'zzzzz');
    expect(find.text('No internships found'), findsOneWidget);

    await _type(tester, '');

    expect(find.text('No internships found'), findsNothing);
    expect(find.text('Search internships'), findsOneWidget);
    // An empty field must not fire a request.
    expect(service.queries, ['zzzzz']);
  });
}
