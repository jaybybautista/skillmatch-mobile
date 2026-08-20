import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:skillmatch/screens/company/company_posting.dart';
import 'package:skillmatch/screens/company/create_post_screen.dart';
import 'package:skillmatch/services/company_service.dart';

/// Records what the wizard sends so the tests can assert on the payload the
/// backend would have received.
class _FakeCompanyService extends CompanyService {
  _FakeCompanyService({this.error});

  final Object? error;
  final calls = <String>[];

  String? jobRole;
  int? slots;
  List<String>? responsibilities;
  List<String>? skills;
  int? updatedId;

  @override
  Future<CompanyPosting> createPosting({
    required String jobRole,
    required int slots,
    required List<String> responsibilities,
    required List<String> skills,
  }) async {
    calls.add('create');
    if (error != null) throw error!;
    this.jobRole = jobRole;
    this.slots = slots;
    this.responsibilities = List.of(responsibilities);
    this.skills = List.of(skills);
    return _posting(title: jobRole, slots: slots);
  }

  @override
  Future<CompanyPosting> updatePosting({
    required int id,
    required String jobRole,
    required int slots,
    required List<String> responsibilities,
    required List<String> skills,
  }) async {
    calls.add('update');
    if (error != null) throw error!;
    updatedId = id;
    this.jobRole = jobRole;
    this.slots = slots;
    this.responsibilities = List.of(responsibilities);
    this.skills = List.of(skills);
    return _posting(id: id, title: jobRole, slots: slots);
  }
}

CompanyPosting _posting({
  int id = 7,
  String title = 'Backend Intern',
  int slots = 3,
  List<String> responsibilities = const ['Build features'],
  List<String> skills = const ['Laravel'],
}) {
  return CompanyPosting.fromJson({
    'id': id,
    'title': title,
    'location': 'Dagupan City',
    'application_count': 0,
    'slots_available': slots,
    'slots_filled': 0,
    'status': 'open',
    'description': responsibilities.join('\n'),
    'responsibilities': responsibilities,
    'skills': skills,
    'posted_at_human': 'just now',
  });
}

/// Waits out a snack bar. It sits over the wizard's footer, so a following
/// tap on "Next" would land on the snack bar instead of the button.
Future<void> _clearSnackBar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

Future<void> _pump(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(MaterialApp(home: screen));
  await tester.pumpAndSettle();
}

/// Fills step 1, adds one responsibility, adds one skill, and stops on the
/// last step without submitting.
Future<void> _fillAllSteps(
  WidgetTester tester, {
  String role = 'Backend Intern',
  String slots = '3',
  String responsibility = 'Build API endpoints',
  String skill = 'Laravel',
}) async {
  await tester.enterText(find.byType(TextField).at(0), role);
  await tester.enterText(find.byType(TextField).at(1), slots);
  await tester.tap(find.text('Next'));
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextField).first, responsibility);
  await tester.tap(find.byIcon(Icons.add).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Next'));
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextField).first, skill);
  await tester.tap(find.byIcon(Icons.add).first);
  await tester.pumpAndSettle();
}

void main() {
  group('creating a posting', () {
    testWidgets('sends the role, slots, responsibilities and skills', (
      tester,
    ) async {
      final service = _FakeCompanyService();
      await _pump(tester, CreatePostScreen(service: service));

      await _fillAllSteps(tester);
      await tester.tap(find.text('Post'));
      await tester.pumpAndSettle();

      expect(service.calls, ['create']);
      expect(service.jobRole, 'Backend Intern');
      expect(service.slots, 3);
      expect(service.responsibilities, ['Build API endpoints']);
      expect(service.skills, ['Laravel']);
    });

    testWidgets('will not advance without a job role and a slot count', (
      tester,
    ) async {
      final service = _FakeCompanyService();
      await _pump(tester, CreatePostScreen(service: service));

      // Nothing typed at all.
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Give the posting a job role first.'), findsOneWidget);
      expect(find.text('Basic Info'), findsOneWidget);
      await _clearSnackBar(tester);

      // A role, but no slots.
      await tester.enterText(find.byType(TextField).at(0), 'Backend Intern');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Basic Info'), findsOneWidget);
      await _clearSnackBar(tester);

      // Zero slots is not a posting anyone can apply to - the server's
      // min:1 rule says the same thing.
      await tester.enterText(find.byType(TextField).at(1), '0');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Basic Info'), findsOneWidget);
      await _clearSnackBar(tester);

      await tester.enterText(find.byType(TextField).at(1), '2');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Responsibilities'), findsOneWidget);
    });

    testWidgets('will not post without a responsibility or a skill', (
      tester,
    ) async {
      final service = _FakeCompanyService();
      await _pump(tester, CreatePostScreen(service: service));

      await tester.enterText(find.byType(TextField).at(0), 'Backend Intern');
      await tester.enterText(find.byType(TextField).at(1), '3');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Add at least one responsibility.'), findsOneWidget);
      await _clearSnackBar(tester);

      await tester.enterText(find.byType(TextField).first, 'Build things');
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Post'));
      await tester.pumpAndSettle();
      expect(find.text('Add at least one required skill.'), findsOneWidget);
      expect(service.calls, isEmpty);
    });

    testWidgets('text typed but never added with "+" still counts', (
      tester,
    ) async {
      final service = _FakeCompanyService();
      await _pump(tester, CreatePostScreen(service: service));

      await tester.enterText(find.byType(TextField).at(0), 'Backend Intern');
      await tester.enterText(find.byType(TextField).at(1), '3');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Typed, but "+" never tapped.
      await tester.enterText(find.byType(TextField).first, 'Write tests');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Skills'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'PHP');
      await tester.tap(find.text('Post'));
      await tester.pumpAndSettle();

      expect(service.responsibilities, ['Write tests']);
      expect(service.skills, ['PHP']);
    });

    testWidgets('says so when the save fails, and stays open', (tester) async {
      final service = _FakeCompanyService(error: Exception('offline'));
      await _pump(tester, CreatePostScreen(service: service));

      await _fillAllSteps(tester);
      await tester.tap(find.text('Post'));
      await tester.pumpAndSettle();

      expect(service.calls, ['create']);
      expect(find.textContaining('Could not post'), findsOneWidget);
      // Still on the wizard, with the work intact.
      expect(find.text('Skills'), findsOneWidget);
      expect(find.text('Laravel'), findsWidgets);
    });
  });

  group('editing a posting', () {
    testWidgets('opens prefilled and saves through updatePosting', (
      tester,
    ) async {
      final service = _FakeCompanyService();
      final existing = _posting(
        id: 12,
        title: 'Product Design Intern',
        slots: 4,
        responsibilities: ['Run design reviews'],
        skills: ['Figma'],
      );

      await _pump(
        tester,
        CreatePostScreen(posting: existing, service: service),
      );

      expect(find.text('Edit Post'), findsOneWidget);
      expect(
        find.widgetWithText(TextField, 'Product Design Intern'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextField, '4'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Run design reviews'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Figma'), findsOneWidget);

      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(service.calls, ['update']);
      expect(service.updatedId, 12);
      expect(service.jobRole, 'Product Design Intern');
      expect(service.slots, 4);
      expect(service.responsibilities, ['Run design reviews']);
      expect(service.skills, ['Figma']);
    });
  });
}
