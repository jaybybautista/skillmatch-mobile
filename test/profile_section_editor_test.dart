import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillmatch/core/api_client.dart';
import 'package:skillmatch/models/student_profile.dart';
import 'package:skillmatch/screens/student/profile/profile_section_editor.dart';

/// Opens the sheet inside a throwaway screen and hands back what it saved.
Future<Map<String, String?>?> _open(
  WidgetTester tester, {
  required List<EditorField> fields,
  Object? failWith,
}) async {
  Map<String, String?>? captured;
  bool? result;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showProfileSectionEditor(
                context: context,
                title: 'Add project',
                fields: fields,
                onSave: (values) async {
                  if (failWith != null) throw failWith;
                  captured = values;
                },
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();

  // Ibinabalik ang naitala. Null pag hindi natuloy ang pag-save.
  addTearDown(() => result);
  return captured;
}

void main() {
  testWidgets('a required field blocks saving until it is filled', (
    tester,
  ) async {
    var saved = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showProfileSectionEditor(
                context: context,
                title: 'Add project',
                fields: [
                  EditorField(key: 'title', label: 'Title', required: true),
                ],
                onSave: (_) async => saved = true,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Title is required.'), findsOneWidget);
    expect(saved, isFalse);
  });

  testWidgets('what was typed is what gets saved, trimmed', (tester) async {
    final captured = <String, String?>{};

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showProfileSectionEditor(
                context: context,
                title: 'Add project',
                fields: [
                  EditorField(key: 'title', label: 'Title', required: true),
                  EditorField(key: 'role', label: 'Role'),
                ],
                onSave: (values) async => captured.addAll(values),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      '  Campus Portal  ',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();

    expect(captured['title'], 'Campus Portal');
    // Blangko, kaya null ang ipinapadala - hindi walang laman na teksto.
    expect(captured['role'], isNull);
  });

  testWidgets('an existing entry opens already filled in', (tester) async {
    await _open(
      tester,
      fields: [
        EditorField(key: 'title', label: 'Title', initial: 'Campus Portal'),
        EditorField(key: 'role', label: 'Role', initial: 'Developer'),
      ],
    );

    expect(find.text('Campus Portal'), findsOneWidget);
    expect(find.text('Developer'), findsOneWidget);
  });

  testWidgets('the server error is shown and the sheet stays open', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showProfileSectionEditor(
                context: context,
                title: 'Add project',
                fields: [EditorField(key: 'title', label: 'Title')],
                onSave: (_) async =>
                    throw ApiException('The title field is required.'),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();

    // Hindi hula ng app ito. Galing mismo sa server, kaparehong-kapareho ng
    // nababasa sa web.
    expect(find.text('The title field is required.'), findsOneWidget);
    expect(find.text('Add project'), findsOneWidget);
  });

  testWidgets('a choice field offers exactly the options given', (
    tester,
  ) async {
    await _open(
      tester,
      fields: [
        EditorField(
          key: 'type',
          label: 'Type',
          initial: 'work',
          type: EditorFieldType.choice,
          choices: const [
            (value: 'work', label: 'Work experience'),
            (value: 'extracurricular', label: 'Extracurricular'),
          ],
        ),
      ],
    );

    expect(find.text('Work experience'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    expect(find.text('Extracurricular'), findsWidgets);
  });

  group('the delete confirmation', () {
    testWidgets('names the entry and can be cancelled', (tester) async {
      bool? answer;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async =>
                    answer = await confirmSectionDelete(context, 'Campus Portal'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Remove "Campus Portal" from your profile?'),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(answer, isFalse);
    });
  });

  group('the profile models', () {
    test('carry the id and raw dates an edit form needs', () {
      final profile = StudentProfile.fromJson({
        'name': 'Jayby',
        'email': 'j@example.com',
        'skills': <String>[],
        'certifications': [
          {
            'id': 5,
            'title': 'Coursera Cert',
            'issue_date': 'Jan 2026',
            'issue_date_raw': '2026-01-10',
            'credential_url': 'https://example.test/cert',
          },
        ],
        'experiences': [
          {
            'id': 7,
            'position': 'IT Intern',
            'type': 'work',
            'start_date': 'Jun 2025',
            'start_date_raw': '2025-06-01',
          },
        ],
        'education_history': [
          {'id': 3, 'institution': 'PSU', 'start_year': 2022, 'end_year': 2026},
        ],
        'projects': [
          {'id': 9, 'title': 'Portal', 'start_date_raw': '2025-08-01'},
        ],
        'achievements': [
          {'id': 11, 'title': 'Award', 'date_awarded_raw': '2026-02-01'},
        ],
      });

      expect(profile.certifications.single.id, 5);
      expect(profile.certifications.single.issueDateRaw, '2026-01-10');
      expect(profile.experiences.single.type, 'work');
      expect(profile.experiences.single.startDateRaw, '2025-06-01');
      expect(profile.educationHistory.single.id, 3);
      expect(profile.educationHistory.single.period, '2022 to 2026');
      expect(profile.projects.single.startDateRaw, '2025-08-01');
      expect(profile.achievements.single.dateAwardedRaw, '2026-02-01');
    });

    test('an ongoing school reads as Present', () {
      final entry = EducationEntry.fromJson({
        'id': 1,
        'institution': 'PSU',
        'start_year': 2022,
      });

      expect(entry.period, '2022 to Present');
    });
  });
}
