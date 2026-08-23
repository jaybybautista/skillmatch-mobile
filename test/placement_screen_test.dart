import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:skillmatch/models/placement.dart';
import 'package:skillmatch/screens/student/placement/placement_screen.dart';
import 'package:skillmatch/services/auth_service.dart';
import 'package:skillmatch/services/placement_service.dart';

class _FakePlacementService extends PlacementService {
  _FakePlacementService(this.payload);

  final Map<String, dynamic> payload;

  @override
  Future<PlacementSummary> fetchPlacement() async =>
      PlacementSummary.fromJson(payload);
}

/// The payload the API returns for a real placement, matching what the web's
/// My Placement page renders.
Map<String, dynamic> _payload({
  String? endDate,
  int? progressPercent,
  int? evaluationScore,
  List<Map<String, dynamic>> history = const [],
}) => {
  'placement': {
    'id': 1,
    'status': 'ongoing',
    'role_title': 'Product Design Intern',
    'company_name': 'SkillMatch',
    'company_initial': 'S',
    'start_date': 'August 08, 2026',
    'end_date': endDate,
    'location': 'Zone 4, Brgy. Alipangpang, Pozorrubio, Pangasinan',
    'coordinator_name': 'Dr. Maria Santos',
    'coordinator_email': 'coordinator.urdaneta@skillmatch.ph',
    'coordinator_dept': 'College of Computing and Information Technology',
    'coordinator_campus': 'Urdaneta City Campus',
    'evaluation_score': evaluationScore,
    'recorded_at': 'August 08, 2026',
    'internship_id': 2,
  },
  'student_campus': 'Urdaneta City Campus',
  'progress_percent': progressPercent,
  'history': history,
};

Future<void> _pump(WidgetTester tester, Map<String, dynamic> payload) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthService>(
      create: (_) => AuthService(),
      child: MaterialApp(
        home: PlacementScreen(
          // A fresh key each time, so pumping a second payload in one test
          // builds a new State and actually reloads.
          key: UniqueKey(),
          service: _FakePlacementService(payload),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Brings a row below the fold into view.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 12 && finder.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(ListView), const Offset(0, -220));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('it shows the fields the web page shows', (tester) async {
    await _pump(tester, _payload());

    expect(find.text('Product Design Intern'), findsOneWidget);
    expect(find.text('SkillMatch'), findsOneWidget);

    expect(find.text('START DATE'), findsOneWidget);
    expect(find.text('August 08, 2026'), findsNWidgets(2));
    expect(find.text('END DATE'), findsOneWidget);
    expect(find.text('Not set'), findsOneWidget);
    expect(find.text('LOCATION'), findsOneWidget);
    expect(find.text('RECORD CREATED'), findsOneWidget);
    expect(find.text('View the original posting'), findsOneWidget);

    await _scrollTo(tester, find.text('Your OJT coordinator'));
    expect(find.text('Dr. Maria Santos'), findsOneWidget);
    expect(find.text('Campus'), findsOneWidget);
    expect(find.text('Urdaneta City Campus'), findsOneWidget);

    await _scrollTo(tester, find.text('Evaluation'));
    expect(
      find.text('No evaluation score has been recorded yet.'),
      findsOneWidget,
    );
  });

  testWidgets('it shows nothing the web page does not', (tester) async {
    await _pump(tester, _payload());

    // The hours tracker and the remarks panel were the app's own inventions.
    // The web records hours and remarks on the placement but never puts them
    // on this page, and the tracker had no data behind it here either.
    for (final gone in [
      'OJT Hours Rendered',
      'Hours Remaining',
      'Log Hours',
      'Remarks',
      'Placement Timeline',
      'Supervising Coordinator',
      'Record',
    ]) {
      expect(
        find.textContaining(gone),
        findsNothing,
        reason: '"$gone" is not on the web page',
      );
    }
  });

  testWidgets('progress measures the period, and only when it has an end', (
    tester,
  ) async {
    // No end date, so there is no period to measure — the web draws no bar.
    await _pump(tester, _payload());
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await _pump(
      tester,
      _payload(endDate: 'February 08, 2027', progressPercent: 40),
    );

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
      find.text('40% of your placement period has passed'),
      findsOneWidget,
    );
  });

  testWidgets('a recorded evaluation shows as a mark out of 100', (
    tester,
  ) async {
    await _pump(tester, _payload(evaluationScore: 92));

    await _scrollTo(tester, find.text('Evaluation'));
    expect(find.text('92'), findsOneWidget);
    expect(find.text('/ 100'), findsOneWidget);
    expect(
      find.text('No evaluation score has been recorded yet.'),
      findsNothing,
    );
  });

  testWidgets('earlier placements are listed underneath', (tester) async {
    await _pump(
      tester,
      _payload(
        history: const [
          {
            'id': 9,
            'status': 'completed',
            'role_title': 'QA Intern',
            'company_name': 'Acme',
            'start_date': 'January 05, 2026',
            'end_date': 'May 30, 2026',
          },
        ],
      ),
    );

    await _scrollTo(tester, find.text('Previous Placements'));
    expect(find.text('QA Intern'), findsOneWidget);
  });
}
