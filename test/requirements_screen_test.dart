import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:skillmatch/models/requirement.dart';
import 'package:skillmatch/screens/requirements/requirement_viewer_screen.dart';
import 'package:skillmatch/screens/requirements/requirements_screen.dart';
import 'package:skillmatch/services/requirement_service.dart';

class _FakeRequirementService extends RequirementService {
  _FakeRequirementService(this.items);

  List<RequirementItem> items;
  final calls = <String>[];

  @override
  Future<List<RequirementItem>> fetchAll() async {
    calls.add('fetchAll');
    return items;
  }

  @override
  Future<RequirementPreview> previewTemplate(int requirementId) async {
    calls.add('previewTemplate:$requirementId');
    return RequirementPreview(kind: PreviewKind.pdf, bytes: const [1, 2, 3]);
  }

  @override
  Future<RequirementPreview> previewUpload(int requirementId) async {
    calls.add('previewUpload:$requirementId');
    return RequirementPreview(kind: PreviewKind.pdf, bytes: const [1, 2, 3]);
  }

  @override
  Future<List<int>> downloadTemplate(int requirementId) async {
    calls.add('downloadTemplate:$requirementId');
    return const [1, 2, 3];
  }

  @override
  Future<List<int>> downloadUpload(int requirementId) async {
    calls.add('downloadUpload:$requirementId');
    return const [1, 2, 3];
  }

  @override
  Future<void> removeUpload(int requirementId) async {
    calls.add('removeUpload:$requirementId');
  }

  @override
  Future<void> submit(int requirementId) async {
    calls.add('submit:$requirementId');
  }

  @override
  Future<void> unsubmit(int requirementId) async {
    calls.add('unsubmit:$requirementId');
  }
}

/// Records the widget type of every route pushed on top, without needing
/// that route's own async work (a real preview fetch, here) to finish.
class _PushRecordingNavigatorObserver extends NavigatorObserver {
  final pushed = <Type>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is MaterialPageRoute) {
      pushed.add(route.builder(route.navigator!.context).runtimeType);
    }
  }
}

RequirementItem _item({
  int id = 1,
  String title = 'Application for Internship',
  bool hasTemplate = true,
  bool hasUpload = false,
  bool isSubmitted = false,
}) {
  return RequirementItem.fromJson({
    'id': id,
    'title': title,
    'file_kind': 'doc',
    'original_filename': '$title.docx',
    'file_size': 45000,
    'readable_size': '45 KB',
    'has_template': hasTemplate,
    'updated_at_human': '3 hours ago',
    'submission': {
      'has_upload': hasUpload,
      'status': isSubmitted ? 'submitted' : 'draft',
      'original_filename': hasUpload ? 'my-copy.docx' : null,
      'file_size': hasUpload ? 20000 : null,
      'readable_size': hasUpload ? '20 KB' : null,
      'file_kind': hasUpload ? 'doc' : null,
      'submitted_at': isSubmitted ? '2026-08-14T00:00:00+00:00' : null,
      'updated_at_human': hasUpload ? '1 hour ago' : null,
    },
  });
}

void main() {
  testWidgets('shows a status pill per requirement', (tester) async {
    final service = _FakeRequirementService([
      _item(id: 1, title: 'Not started form'),
      _item(id: 2, title: 'Draft form', hasUpload: true),
      _item(id: 3, title: 'Submitted form', hasUpload: true, isSubmitted: true),
    ]);

    await tester.pumpWidget(MaterialApp(home: RequirementsScreen(service: service)));
    await tester.pumpAndSettle();

    expect(find.text('Not started'), findsOneWidget);
    expect(find.text('Draft uploaded'), findsOneWidget);
    expect(find.text('Submitted'), findsOneWidget);
  });

  testWidgets('the empty state names what is missing', (tester) async {
    final service = _FakeRequirementService(const []);

    await tester.pumpWidget(MaterialApp(home: RequirementsScreen(service: service)));
    await tester.pumpAndSettle();

    expect(find.text('No requirements published yet'), findsOneWidget);
  });

  testWidgets('tapping a card opens the template viewer', (tester) async {
    final service = _FakeRequirementService([_item()]);
    final observer = _PushRecordingNavigatorObserver();

    await tester.pumpWidget(MaterialApp(
      navigatorObservers: [observer],
      home: RequirementsScreen(service: service),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Application for Internship'));
    // Bounded pumps only — RequirementViewerScreen kicks off its own preview
    // fetch, which this test has no need to wait out.
    await tester.pump();
    await tester.pump();

    expect(observer.pushed, contains(RequirementViewerScreen));
  });

  testWidgets('Submit to coordinator calls the service and reloads', (tester) async {
    final service = _FakeRequirementService([_item(hasUpload: true)]);

    await tester.pumpWidget(MaterialApp(home: RequirementsScreen(service: service)));
    await tester.pumpAndSettle();

    // Submit/withdraw/remove only live on the My Uploads tab's menu.
    await tester.tap(find.text('My Uploads'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit to coordinator'));
    await tester.pumpAndSettle();

    expect(service.calls, contains('submit:1'));
  });

  testWidgets('Withdraw submission calls unsubmit', (tester) async {
    final service = _FakeRequirementService([_item(hasUpload: true, isSubmitted: true)]);

    await tester.pumpWidget(MaterialApp(home: RequirementsScreen(service: service)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('My Uploads'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Withdraw submission'));
    await tester.pumpAndSettle();

    expect(service.calls, contains('unsubmit:1'));
  });

  testWidgets('Remove upload asks for confirmation before deleting', (tester) async {
    final service = _FakeRequirementService([_item(hasUpload: true)]);

    await tester.pumpWidget(MaterialApp(home: RequirementsScreen(service: service)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('My Uploads'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove upload'));
    await tester.pumpAndSettle();

    // Not removed yet — the confirm dialog is up first.
    expect(service.calls, isNot(contains('removeUpload:1')));
    expect(find.text('Remove upload?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(service.calls, contains('removeUpload:1'));
  });

  testWidgets('a requirement with no template yet is not tappable', (tester) async {
    final service = _FakeRequirementService([_item(hasTemplate: false)]);
    final observer = _PushRecordingNavigatorObserver();

    await tester.pumpWidget(MaterialApp(
      navigatorObservers: [observer],
      home: RequirementsScreen(service: service),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Application for Internship'));
    await tester.pumpAndSettle();

    expect(observer.pushed, isNot(contains(RequirementViewerScreen)));
  });

  group('Coordinator Forms / My Uploads split', () {
    testWidgets('defaults to Coordinator Forms and lists every form', (tester) async {
      final service = _FakeRequirementService([
        _item(id: 1, title: 'Not uploaded yet'),
        _item(id: 2, title: 'Already uploaded', hasUpload: true),
      ]);

      await tester.pumpWidget(MaterialApp(home: RequirementsScreen(service: service)));
      await tester.pumpAndSettle();

      expect(find.text('Not uploaded yet'), findsOneWidget);
      expect(find.text('Already uploaded'), findsOneWidget);
    });

    testWidgets('My Uploads only lists what the student has actually uploaded', (tester) async {
      final service = _FakeRequirementService([
        _item(id: 1, title: 'Not uploaded yet'),
        _item(id: 2, title: 'Already uploaded', hasUpload: true),
      ]);

      await tester.pumpWidget(MaterialApp(home: RequirementsScreen(service: service)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('My Uploads'));
      await tester.pumpAndSettle();

      expect(find.text('Not uploaded yet'), findsNothing);
      expect(find.text('Already uploaded'), findsOneWidget);
    });

    testWidgets('My Uploads shows its own empty state when nothing is uploaded', (tester) async {
      final service = _FakeRequirementService([_item(id: 1, title: 'Not uploaded yet')]);

      await tester.pumpWidget(MaterialApp(home: RequirementsScreen(service: service)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('My Uploads'));
      await tester.pumpAndSettle();

      expect(find.text('Nothing uploaded yet'), findsOneWidget);
    });

    testWidgets('tapping a card in My Uploads opens the uploaded copy, not the template', (tester) async {
      final service = _FakeRequirementService([_item(id: 1, hasUpload: true)]);

      await tester.pumpWidget(MaterialApp(home: RequirementsScreen(service: service)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('My Uploads'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Application for Internship'));
      await tester.pump();
      await tester.pump();

      expect(service.calls, contains('previewUpload:1'));
      expect(service.calls, isNot(contains('previewTemplate:1')));
    });

    testWidgets('the Coordinator Forms menu never offers submit/withdraw/remove', (tester) async {
      final service = _FakeRequirementService([_item(id: 1, hasUpload: true, isSubmitted: true)]);

      await tester.pumpWidget(MaterialApp(home: RequirementsScreen(service: service)));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('View template'), findsOneWidget);
      expect(find.text('Replace my copy'), findsOneWidget);
      expect(find.text('Withdraw submission'), findsNothing);
      expect(find.text('Remove upload'), findsNothing);
    });

    testWidgets('the My Uploads menu never offers template actions', (tester) async {
      final service = _FakeRequirementService([_item(id: 1, hasUpload: true)]);

      await tester.pumpWidget(MaterialApp(home: RequirementsScreen(service: service)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('My Uploads'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('View my copy'), findsOneWidget);
      expect(find.text('View template'), findsNothing);
      expect(find.text('Download template'), findsNothing);
    });
  });
}
