import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:skillmatch/core/app_routing.dart';
import 'package:skillmatch/core/resume_updates.dart';

/// A screen that reloads whenever a resume changes, standing in for the
/// resume list, the section list, the preview and the profile — all of which
/// subscribe the same way.
class _Subscriber extends StatefulWidget {
  const _Subscriber({required this.onReload});

  final VoidCallback onReload;

  @override
  State<_Subscriber> createState() => _SubscriberState();
}

class _SubscriberState extends State<_Subscriber> with ResumeUpdateListener {
  @override
  void onResumeChanged() => widget.onReload();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Wraps a subscriber in the same navigator setup the app uses, so the
/// mixin can tell whether it is covered.
Widget _app(Widget home) => MaterialApp(
  navigatorObservers: [routeObserver],
  home: home,
);

void main() {
  testWidgets('a change reaches a screen that is already on screen', (
    tester,
  ) async {
    var reloads = 0;

    await tester.pumpWidget(
      _app(_Subscriber(onReload: () => reloads++)),
    );

    expect(reloads, 0, reason: 'nothing has changed yet');

    ResumeUpdates.instance.changed();
    await tester.pump();

    expect(reloads, 1);

    ResumeUpdates.instance.changed();
    ResumeUpdates.instance.changed();
    await tester.pump();

    expect(reloads, 3, reason: 'every change is a reload, not just the first');
  });

  testWidgets('every screen showing resume data hears the same change', (
    tester,
  ) async {
    var list = 0;
    var preview = 0;
    var profile = 0;

    await tester.pumpWidget(
      _app(
        Column(
          children: [
            _Subscriber(onReload: () => list++),
            _Subscriber(onReload: () => preview++),
            _Subscriber(onReload: () => profile++),
          ],
        ),
      ),
    );

    ResumeUpdates.instance.changed();
    await tester.pump();

    // The point of the whole thing: one edit, and nothing anywhere is left
    // showing what the resume used to say.
    expect([list, preview, profile], [1, 1, 1]);
  });

  testWidgets('a screen that has been closed is not called, and does not leak', (
    tester,
  ) async {
    var reloads = 0;

    await tester.pumpWidget(
      _app(_Subscriber(onReload: () => reloads++)),
    );

    await tester.pumpWidget(_app(const SizedBox.shrink()));

    ResumeUpdates.instance.changed();
    await tester.pump();

    expect(
      reloads,
      0,
      reason: 'a disposed screen unsubscribes itself, so nothing calls '
          'setState on it after it is gone',
    );
  });

  testWidgets(
    'a covered screen waits, then catches up once when it is uncovered',
    (tester) async {
      var reloads = 0;
      final key = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          navigatorObservers: [routeObserver],
          home: _Subscriber(onReload: () => reloads++),
        ),
      );

      // An editor opens on top, the way the section editors do.
      key.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const SizedBox.shrink()),
      );
      await tester.pumpAndSettle();

      // Autosave firing repeatedly while the student types.
      for (var i = 0; i < 5; i++) {
        ResumeUpdates.instance.changed();
      }
      await tester.pump();

      expect(
        reloads,
        0,
        reason: 'nothing is refetched for a screen nobody can see',
      );

      key.currentState!.pop();
      await tester.pumpAndSettle();

      expect(
        reloads,
        1,
        reason: 'five changes collapse into the one reload that matters',
      );
    },
  );

  testWidgets('a screen opened after a change starts up to date', (
    tester,
  ) async {
    ResumeUpdates.instance.changed();

    var reloads = 0;
    await tester.pumpWidget(
      _app(_Subscriber(onReload: () => reloads++)),
    );
    await tester.pump();

    // It fetched on build, so the change it missed is already in what it
    // just loaded — reloading again would be a wasted request.
    expect(reloads, 0);
  });
}
