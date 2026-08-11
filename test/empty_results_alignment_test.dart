import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillmatch/widgets/empty_results.dart';

/// The empty state must sit on the screen's centre line. Eyeballing a
/// screenshot isn't proof, so these measure it.
void main() {
  const title = 'No internships found';
  const hint = 'Try a different keyword.';

  Future<void> pumpIn(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
    await tester.pumpAndSettle();
  }

  void expectHorizontallyCentred(WidgetTester tester) {
    final screenCentre = tester.getSize(find.byType(MaterialApp)).width / 2;

    for (final finder in [find.text(title), find.text(hint), find.byType(Icon)]) {
      final centre = tester.getCenter(finder).dx;
      expect(
        (centre - screenCentre).abs() < 1.0,
        isTrue,
        reason: 'expected content centred at $screenCentre, was at $centre',
      );
    }
  }

  testWidgets('is centred as a direct body child', (tester) async {
    await pumpIn(tester, const EmptyResults(title: title, hint: hint));
    expectHorizontallyCentred(tester);
  });

  testWidgets('is centred inside a ListView', (tester) async {
    await pumpIn(
      tester,
      ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: const [EmptyResults(title: title, hint: hint)],
      ),
    );
    expectHorizontallyCentred(tester);
  });

  testWidgets('is centred inside a Column, where a stray stretch would show', (tester) async {
    await pumpIn(
      tester,
      const Column(children: [EmptyResults(title: title, hint: hint)]),
    );
    expectHorizontallyCentred(tester);
  });
}
