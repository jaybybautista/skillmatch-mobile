import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillmatch/core/app_theme.dart';
import 'package:skillmatch/widgets/app_text_field.dart';
import 'package:skillmatch/widgets/select_or_other_field.dart';

const _long =
    'Bachelor of Science in Information Technology major in Web and Mobile Technologies';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  group('a long option is readable, not cut off', () {
    testWidgets('the dropdown lets the text wrap instead of clipping it', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(380, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          AppDropdownField<String>(
            label: 'Course',
            value: _long,
            items: const [_long],
            itemLabel: (c) => c,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Dati, ellipsis ito, kaya pinuputol yung pangalan sa isang linya.
      final texts = tester
          .widgetList<Text>(find.text(_long))
          .toList();

      expect(texts, isNotEmpty);
      for (final text in texts) {
        expect(text.overflow, isNot(TextOverflow.ellipsis));
      }

      // Dalawang linya pataas, ibig sabihin bumaba na ito imbes na maputol.
      final rendered = tester.renderObject<RenderBox>(
        find.text(_long).first,
      );
      expect(rendered.size.height, greaterThan(20));
    });
  });

  group('picking Others', () {
    testWidgets('the typing box only appears once Others is chosen', (
      tester,
    ) async {
      String? picked = 'Insurance';

      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) => SelectOrOtherField(
              label: 'Industry',
              value: picked,
              options: const ['Insurance', 'Healthcare'],
              onChanged: (value) => setState(() => picked = value),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppTextField, 'Type your own'), findsNothing);

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(kOtherOption).last);
      await tester.pumpAndSettle();

      expect(find.text('Type your own'), findsOneWidget);
    });

    testWidgets('what they type is what gets reported, never the word Others', (
      tester,
    ) async {
      String? picked;

      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) => SelectOrOtherField(
              label: 'Industry',
              value: picked,
              options: const ['Insurance', 'Healthcare'],
              onChanged: (value) => setState(() => picked = value),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(kOtherOption).last);
      await tester.pumpAndSettle();

      // Blangko pa, kaya wala pang sagot - hindi yung salitang Others.
      expect(picked, isNull);

      await tester.enterText(find.byType(TextFormField), 'Life Insurance');
      await tester.pumpAndSettle();

      expect(picked, 'Life Insurance');
    });
  });

  group('a value the list does not know', () {
    testWidgets('is kept and shown, not silently dropped', (tester) async {
      // Ganito ang lumalabas sa setup wizard: may kuwit, kaya kahit kailan
      // hindi ito tumutugma sa listahan ng campus.
      const fromWizard =
          'Bachelor of Science in Information Technology, major in Web and Mobile Technologies';

      await tester.pumpWidget(
        _wrap(
          SelectOrOtherField(
            label: 'Course',
            value: fromWizard,
            options: const [_long],
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final field = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );

      expect(field.initialValue, fromWizard);
    });

    testWidgets('Others always sits at the end of the list', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SelectOrOtherField(
            label: 'Industry',
            value: null,
            options: const ['Insurance', 'Healthcare'],
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Binubuksan ito para makita ang buong listahan. Walang items na
      // matatanong sa DropdownButtonFormField mismo sa bersyong ito.
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      expect(find.text('Insurance'), findsWidgets);
      expect(find.text('Healthcare'), findsWidgets);
      expect(find.text(kOtherOption), findsWidgets);
    });
  });
}
