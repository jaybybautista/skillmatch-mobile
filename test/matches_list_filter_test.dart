import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillmatch/models/internship.dart';
import 'package:skillmatch/screens/matches/matches_list_screen.dart';
import 'package:skillmatch/services/internship_service.dart';

class _FakeInternshipService extends InternshipService {
  final filters = <InternshipFilter>[];

  @override
  Future<List<Internship>> fetchAll({
    String query = '',
    InternshipFilter filter = InternshipFilter.topMatches,
  }) async {
    filters.add(filter);
    return [
      Internship.fromJson({
        'id': 1,
        'title': 'Product Design Intern',
        'company_name': 'Creatix Studio',
        'distance_km': 12.4,
        'distance_formatted': '12.4 km away',
      }),
    ];
  }
}

void main() {
  Future<void> pump(WidgetTester tester, _FakeInternshipService service) async {
    await tester.pumpWidget(MaterialApp(home: MatchesListScreen(service: service)));
    await tester.pumpAndSettle();
  }

  testWidgets('the ordering lives on the top-bar button, not in a chip row', (tester) async {
    final service = _FakeInternshipService();
    await pump(tester, service);

    // No chips below the search field any more.
    expect(find.text('Proximity Based'), findsNothing);
    expect(find.text('All'), findsNothing);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Top Matches'), findsOneWidget);
    expect(find.text('Proximity Based'), findsOneWidget);
  });

  testWidgets('picking an ordering re-queries with it', (tester) async {
    final service = _FakeInternshipService();
    await pump(tester, service);

    expect(service.filters, [InternshipFilter.topMatches]);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Proximity Based'));
    await tester.pumpAndSettle();

    expect(service.filters.last, InternshipFilter.proximity);
    // Distance is shown once it's what the list is sorted on.
    expect(find.text('12.4 km away'), findsOneWidget);
  });

  testWidgets('re-picking the active ordering does not refetch', (tester) async {
    final service = _FakeInternshipService();
    await pump(tester, service);

    final callsBefore = service.filters.length;

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Top Matches'));
    await tester.pumpAndSettle();

    expect(service.filters.length, callsBefore);
  });
}
