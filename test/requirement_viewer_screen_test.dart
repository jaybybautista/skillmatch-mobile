import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printing/printing.dart';

import 'package:skillmatch/models/requirement.dart';
import 'package:skillmatch/screens/requirements/requirement_viewer_screen.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

/// A real, decodable 1x1 transparent PNG — enough for Image.memory to
/// actually resolve a codec, unlike a few arbitrary bytes.
final _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

void main() {
  testWidgets('an image preview renders inline and zoomable', (tester) async {
    await tester.pumpWidget(_wrap(RequirementViewerScreen(
      title: 'Consent and Waiver',
      subtitle: 'Original copy from your coordinator',
      loadPreview: () async => RequirementPreview(kind: PreviewKind.image, bytes: _onePixelPng),
      loadDownload: () async => const [1, 2, 3],
      downloadFilename: 'consent.png',
    )));
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('an unsupported file falls back to a download prompt', (tester) async {
    var downloaded = false;

    await tester.pumpWidget(_wrap(RequirementViewerScreen(
      title: 'Odd Format',
      subtitle: 'Original copy from your coordinator',
      loadPreview: () async => RequirementPreview(kind: PreviewKind.none, message: 'This kind of file cannot be shown here.'),
      loadDownload: () async {
        downloaded = true;
        return const [1, 2, 3];
      },
      downloadFilename: 'odd.xyz',
    )));
    await tester.pumpAndSettle();

    expect(find.text('This kind of file cannot be shown here.'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Download instead'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Download instead'));
    // Bounded pump: the actual OS share sheet is a platform call this test
    // has no need (or ability) to wait out.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(downloaded, isTrue);
  });

  testWidgets('a pdf preview builds a PdfPreview widget', (tester) async {
    await tester.pumpWidget(_wrap(RequirementViewerScreen(
      title: 'MOA Template',
      subtitle: 'Original copy from your coordinator',
      loadPreview: () async => RequirementPreview(kind: PreviewKind.pdf, bytes: const [1, 2, 3]),
      loadDownload: () async => const [1, 2, 3],
      downloadFilename: 'moa.pdf',
    )));

    // Bounded pumps only: PdfPreview rasterizes through a platform channel
    // that isn't available under flutter test, so this only checks the
    // preview branched to the right widget, not that it finished rendering.
    await tester.pump();
    await tester.pump();

    expect(find.byType(PdfPreview), findsOneWidget);
  });
}
