import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillmatch/models/student_profile.dart';
import 'package:skillmatch/screens/student/profile/profile_screen.dart';
import 'package:skillmatch/services/profile_service.dart';

/// Stands in for the server so the screen can be driven without a network.
class _FakeProfileService extends ProfileService {
  _FakeProfileService(this.profile);

  StudentProfile profile;
  final calls = <String>[];

  @override
  Future<StudentProfile> fetchStudentProfile() async => profile;

  @override
  Future<void> saveProject({
    int? id,
    required String title,
    String? role,
    String? description,
    String? link,
    String? startDate,
    String? endDate,
  }) async {
    calls.add('saveProject id=$id title=$title role=$role');
  }

  @override
  Future<void> deleteProject(int id) async => calls.add('deleteProject $id');

  @override
  Future<void> updateSummary(String summary) async {
    calls.add('updateSummary $summary');
  }
}

StudentProfile _profile() => StudentProfile.fromJson({
  'name': 'Jayby Bautista',
  'email': 'jayby@example.com',
  'course': 'BS Information Technology',
  'campus': 'Urdaneta',
  'professional_summary': 'Backend-leaning IT student.',
  'skills': ['PHP', 'Laravel'],
  'certifications': <Map<String, dynamic>>[],
  'experiences': <Map<String, dynamic>>[],
  'education_history': [
    {'id': 3, 'institution': 'PSU Urdaneta', 'start_year': 2022},
  ],
  'projects': [
    {'id': 9, 'title': 'Campus Portal', 'role': 'Developer'},
  ],
  'achievements': <Map<String, dynamic>>[],
});

Future<void> _pump(WidgetTester tester, _FakeProfileService service) async {
  await tester.pumpWidget(MaterialApp(home: ProfileScreen(service: service)));
  await tester.pumpAndSettle();
}

/// The sections sit in a ListView, so anything below the fold is not built
/// until it is scrolled to.
Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    250,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the one-off sections offer Edit', (tester) async {
    await _pump(tester, _FakeProfileService(_profile()));

    // Yung buod at yung skills, hindi listahan - inaayos, hindi dinadagdagan.
    expect(find.text('Edit'), findsWidgets);
  });

  testWidgets('every list section offers a way to add a row', (tester) async {
    await _pump(tester, _FakeProfileService(_profile()));

    for (final section in [
      'Education',
      'Certification',
      'Experience',
      'Projects',
      'Achievements',
    ]) {
      await _scrollTo(tester, find.text(section));

      final addButton = find.descendant(
        of: find.ancestor(
          of: find.text(section),
          matching: find.byType(Row),
        ).first,
        matching: find.text('Add'),
      );

      expect(addButton, findsOneWidget, reason: '$section has no Add button');
    }
  });

  testWidgets('a row opens the editor already filled in', (tester) async {
    final service = _FakeProfileService(_profile());
    await _pump(tester, service);

    await _scrollTo(tester, find.text('Campus Portal'));

    await tester.tap(find.byIcon(Icons.more_vert).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit').last);
    await tester.pumpAndSettle();

    expect(find.text('Edit project'), findsOneWidget);
    // Nakalagay na yung dati, hindi blangko.
    expect(find.text('Campus Portal'), findsWidgets);
    expect(find.text('Developer'), findsWidgets);
  });

  testWidgets('editing a row sends its id, so it updates rather than adds', (
    tester,
  ) async {
    final service = _FakeProfileService(_profile());
    await _pump(tester, service);

    await _scrollTo(tester, find.text('Campus Portal'));

    await tester.tap(find.byIcon(Icons.more_vert).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();

    expect(
      service.calls,
      contains('saveProject id=9 title=Campus Portal role=Developer'),
    );
  });

  testWidgets('removing a row asks first and can be cancelled', (tester) async {
    final service = _FakeProfileService(_profile());
    await _pump(tester, service);

    await _scrollTo(tester, find.text('Campus Portal'));

    await tester.tap(find.byIcon(Icons.more_vert).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove').last);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Remove "Campus Portal" from your profile?'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(service.calls, isEmpty);
  });

  testWidgets('the summary editor saves what was typed', (tester) async {
    final service = _FakeProfileService(_profile());
    await _pump(tester, service);

    await tester.tap(find.text('Edit').first);
    await tester.pumpAndSettle();

    expect(find.text('Professional summary'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'About you'),
      'Third-year IT student.',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save summary'));
    await tester.pumpAndSettle();

    expect(service.calls, contains('updateSummary Third-year IT student.'));
  });
}
