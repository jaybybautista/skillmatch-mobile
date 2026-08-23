import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:skillmatch/core/app_routing.dart';
import 'package:skillmatch/core/screen_refresh.dart';

/// Stands in for a home screen: loaded once on build, and held by the launch
/// gate for the whole session rather than rebuilt.
class _Home extends StatefulWidget {
  const _Home({required this.onLoad});

  final VoidCallback onLoad;

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> with RefreshOnReveal {
  @override
  void initState() {
    super.initState();
    widget.onLoad();
  }

  @override
  void onReveal() => widget.onLoad();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  testWidgets('a home screen reloads each time it is uncovered', (
    tester,
  ) async {
    var loads = 0;
    final navigator = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [routeObserver],
        home: _Home(onLoad: () => loads++),
      ),
    );

    expect(loads, 1, reason: 'the initial load');

    // Something is done on top of it — accepting an applicant, say, which
    // changes the slot counts this screen is showing.
    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const SizedBox.shrink()),
    );
    await tester.pumpAndSettle();

    expect(loads, 1, reason: 'nothing to do while it is covered');

    // The sidebar's Home unwinds to this same screen rather than building a
    // new one, so without a reload here it would still show what it loaded
    // when the app started.
    navigator.currentState!.popUntil((route) => route.isFirst);
    await tester.pumpAndSettle();

    expect(loads, 2);

    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const SizedBox.shrink()),
    );
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();

    expect(loads, 3, reason: 'every return, not just the first');
  });

  testWidgets('a closed screen stops listening', (tester) async {
    var loads = 0;

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [routeObserver],
        home: _Home(onLoad: () => loads++),
      ),
    );
    expect(loads, 1);

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [routeObserver],
        home: const SizedBox.shrink(),
      ),
    );
    await tester.pumpAndSettle();

    expect(loads, 1, reason: 'it unsubscribed itself on the way out');
  });
}
