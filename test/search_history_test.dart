import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillmatch/models/internship.dart';
import 'package:skillmatch/models/search_history_entry.dart';
import 'package:skillmatch/screens/student/matches/internship_search_screen.dart';
import 'package:skillmatch/services/internship_service.dart';
import 'package:skillmatch/services/search_history_service.dart';
import 'package:skillmatch/widgets/search_history_list.dart';

class _FakeInternshipService extends InternshipService {
  @override
  Future<List<Internship>> fetchAll({
    String query = '',
    InternshipFilter filter = InternshipFilter.topMatches,
  }) async => const [];
}

/// Stands in for the server so the list can be driven without a network.
class _FakeHistoryService extends SearchHistoryService {
  _FakeHistoryService([List<SearchHistoryEntry>? entries])
    : entries = entries ?? [];

  List<SearchHistoryEntry> entries;
  final recordedTerms = <String>[];
  final recordedEntities = <String>[];
  final forgotten = <int>[];
  final cleared = <String>[];

  @override
  Future<List<SearchHistoryEntry>> recent(String context) async => entries;

  @override
  Future<void> recordTerm(String context, String term) async {
    recordedTerms.add('$context:$term');
  }

  @override
  Future<void> recordEntity(
    String context, {
    required String entityType,
    required int entityId,
    required String label,
    String? subtitle,
    String? imageUrl,
    String? initials,
  }) async {
    recordedEntities.add('$context:$entityType:$entityId:$label');
  }

  @override
  Future<void> forget(int id) async => forgotten.add(id);

  @override
  Future<void> clear(String context) async => cleared.add(context);
}

const _term = SearchHistoryEntry(
  id: 1,
  kind: 'term',
  label: 'web developer',
  term: 'web developer',
);

const _entity = SearchHistoryEntry(
  id: 2,
  kind: 'entity',
  label: 'AstraM',
  entityType: 'company',
  entityId: 11,
  subtitle: 'Information Technology',
  initials: 'AS',
);

Future<void> _pumpList(
  WidgetTester tester,
  _FakeHistoryService service, {
  ValueChanged<String>? onTerm,
  ValueChanged<SearchHistoryEntry>? onEntity,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SearchHistoryList(
          context: SearchContext.internships,
          service: service,
          onTermPicked: onTerm ?? (_) {},
          onEntityPicked: onEntity,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('a typed word shows as plain text with a clock', (tester) async {
    await _pumpList(tester, _FakeHistoryService([_term]));

    expect(find.text('Recent searches'), findsOneWidget);
    expect(find.text('web developer'), findsOneWidget);
    expect(find.byIcon(Icons.history), findsOneWidget);
  });

  testWidgets('an opened result shows as a tile with its subtitle', (
    tester,
  ) async {
    await _pumpList(tester, _FakeHistoryService([_entity]));

    expect(find.text('AstraM'), findsOneWidget);
    expect(find.text('Information Technology'), findsOneWidget);
    // Walang larawan itong isang ito, kaya yung unang dalawang letra ang
    // pumapalit - hindi yung orasan ng tinipa lang.
    expect(find.text('AS'), findsOneWidget);
    expect(find.byIcon(Icons.history), findsNothing);
  });

  testWidgets('nothing is drawn when there is no history', (tester) async {
    await _pumpList(tester, _FakeHistoryService());

    expect(find.text('Recent searches'), findsNothing);
  });

  testWidgets('the x drops just that row and tells the server', (tester) async {
    final service = _FakeHistoryService([_term, _entity]);
    await _pumpList(tester, service);

    expect(find.byIcon(Icons.close), findsNWidgets(2));

    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pump();

    expect(service.forgotten, [1]);
    expect(find.text('web developer'), findsNothing);
    expect(find.text('AstraM'), findsOneWidget);
  });

  testWidgets('clear all empties the list', (tester) async {
    final service = _FakeHistoryService([_term, _entity]);
    await _pumpList(tester, service);

    await tester.tap(find.text('Clear all'));
    await tester.pump();

    expect(service.cleared, [SearchContext.internships]);
    expect(find.text('Recent searches'), findsNothing);
  });

  testWidgets('tapping a word hands it back to be searched again', (
    tester,
  ) async {
    String? picked;
    await _pumpList(
      tester,
      _FakeHistoryService([_term]),
      onTerm: (term) => picked = term,
    );

    await tester.tap(find.text('web developer'));
    await tester.pump();

    expect(picked, 'web developer');
  });

  testWidgets('tapping a tile hands back the whole entry, not its name', (
    tester,
  ) async {
    SearchHistoryEntry? picked;
    await _pumpList(
      tester,
      _FakeHistoryService([_entity]),
      onEntity: (entry) => picked = entry,
    );

    await tester.tap(find.text('AstraM'));
    await tester.pump();

    expect(picked?.entityType, 'company');
    expect(picked?.entityId, 11);
  });

  testWidgets('a tile falls back to searching when the screen cannot open it', (
    tester,
  ) async {
    String? picked;
    await _pumpList(
      tester,
      _FakeHistoryService([_entity]),
      onTerm: (term) => picked = term,
    );

    await tester.tap(find.text('AstraM'));
    await tester.pump();

    expect(picked, 'AstraM');
  });

  testWidgets('the search screen shows history before anything is typed', (
    tester,
  ) async {
    final history = _FakeHistoryService([_term]);

    await tester.pumpWidget(
      MaterialApp(
        home: InternshipSearchScreen(
          service: _FakeInternshipService(),
          historyService: history,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Recent searches'), findsOneWidget);
    expect(find.text('web developer'), findsOneWidget);
    // Nandiyan pa rin yung dating paanyaya, nasa ilalim lang ng listahan.
    expect(find.text('Search internships'), findsOneWidget);
  });

  testWidgets('the search screen records the word only once it is submitted', (
    tester,
  ) async {
    final history = _FakeHistoryService();

    await tester.pumpWidget(
      MaterialApp(
        home: InternshipSearchScreen(
          service: _FakeInternshipService(),
          historyService: history,
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'web dev');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    // Tinipa lang, hindi pa ipinasa - wala pang dapat maitala.
    expect(history.recordedTerms, isEmpty);

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump();

    expect(history.recordedTerms, ['${SearchContext.internships}:web dev']);
  });
}
