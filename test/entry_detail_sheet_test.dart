import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillmatch/core/app_theme.dart';
import 'package:skillmatch/screens/student/profile/entry_detail_sheet.dart';

Future<void> _open(WidgetTester tester, List<EntryDetail> details) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showEntryDetails(
                context,
                title: 'Pangasinan State University',
                icon: Icons.school_outlined,
                details: details,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('it shows the whole entry, not just what the card fits', (
    tester,
  ) async {
    await _open(tester, const [
      EntryDetail('Institution', 'Pangasinan State University'),
      EntryDetail('Degree', 'BS Information Technology'),
      EntryDetail('Field of study', 'Web and Mobile Technologies'),
      EntryDetail('End year', 'Ongoing'),
    ]);

    expect(find.text('Pangasinan State University'), findsWidgets);
    expect(find.text('INSTITUTION'), findsOneWidget);
    expect(find.text('BS Information Technology'), findsOneWidget);
    expect(find.text('Web and Mobile Technologies'), findsOneWidget);
    expect(find.text('Ongoing'), findsOneWidget);
  });

  testWidgets('a blank field is left out rather than shown empty', (
    tester,
  ) async {
    await _open(tester, const [
      EntryDetail('Institution', 'Pangasinan State University'),
      EntryDetail('Degree', null),
      EntryDetail('Field of study', '   '),
      EntryDetail('Description', ''),
    ]);

    expect(find.text('INSTITUTION'), findsOneWidget);
    expect(find.text('DEGREE'), findsNothing);
    expect(find.text('FIELD OF STUDY'), findsNothing);
    expect(find.text('DESCRIPTION'), findsNothing);
  });

  testWidgets('an entry with nothing else filled in says so', (tester) async {
    await _open(tester, const [
      EntryDetail('Degree', null),
      EntryDetail('Description', ''),
    ]);

    expect(find.text('Nothing else was filled in for this one.'), findsOneWidget);
  });

  _tapFeedbackTests();

  testWidgets('a long description wraps instead of being cut', (tester) async {
    const long =
        'Built the matching engine, the resume parser and the assessment '
        'builder, then wrote the migration that moved every existing record '
        'across without downtime.';

    await _open(tester, const [EntryDetail('Description', long)]);

    final text = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(text.data, long);

    // Dalawang linya pataas, ibig sabihin bumaba ito imbes na maputol.
    final box = tester.renderObject<RenderBox>(find.byType(SelectableText));
    expect(box.size.height, greaterThan(30));
  });
}

void _tapFeedbackTests() {
  testWidgets('the sheet has finished sliding in by 170ms', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showEntryDetails(
                  context,
                  title: 'Clinic Management System',
                  icon: Icons.lightbulb_outline,
                  details: const [EntryDetail('Role', 'Lead developer')],
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 170));

    // Nasaan na ito sa ika-170, at saan ito titigil.
    final atCutoff = tester.getTopLeft(find.text('Lead developer')).dy;
    await tester.pumpAndSettle();
    final settled = tester.getTopLeft(find.text('Lead developer')).dy;

    // Dati, dalawang daan at limampu ang nakatakda - kaya sa ika-170,
    // umaahon pa ito at mas mababa pa sa hinihintuan nito. Yun ang ramdam
    // nilang paghihintay.
    expect(
      atCutoff,
      moreOrLessEquals(settled, epsilon: 1),
      reason: 'the sheet should already be in place, not still climbing',
    );
  });
}
