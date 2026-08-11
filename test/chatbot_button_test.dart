import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillmatch/core/app_routing.dart';
import 'package:skillmatch/widgets/draggable_chatbot_button.dart';

Widget _host({VoidCallback? onTap}) => MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            const SizedBox.expand(),
            DraggableChatbotButton(onTap: onTap),
          ],
        ),
      ),
    );

/// Mirrors the home screen: the button floats over a scrollable list, so the
/// button's pan recognizer and the list's scroll recognizer actually compete
/// in the gesture arena. Without a competitor the button always wins on its
/// own and the drag threshold is never exercised.
Widget _hostOverList({required ScrollController controller, VoidCallback? onTap}) => MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            ListView.builder(
              controller: controller,
              itemCount: 60,
              itemBuilder: (context, i) => SizedBox(height: 80, child: Text('item $i')),
            ),
            DraggableChatbotButton(onTap: onTap),
          ],
        ),
      ),
    );

void main() {
  testWidgets('starts in the bottom-right and can be dragged elsewhere', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    final start = tester.getCenter(find.byType(AnimatedScale));
    final screen = tester.getSize(find.byType(Scaffold));
    expect(start.dx, greaterThan(screen.width / 2), reason: 'should start on the right');
    expect(start.dy, greaterThan(screen.height / 2), reason: 'should start near the bottom');

    await tester.drag(find.byType(AnimatedScale), const Offset(-160, -220));
    await tester.pumpAndSettle();

    final moved = tester.getCenter(find.byType(AnimatedScale));
    expect(moved.dx, lessThan(start.dx));
    expect(moved.dy, lessThan(start.dy));
  });

  testWidgets('starts tracking within ~6px, while the finger is still down', (tester) async {
    final controller = ScrollController();
    // onTap supplied on purpose: it's the tap recogniser competing for the
    // gesture arena that used to delay the drag by ~18px.
    await tester.pumpWidget(_hostOverList(controller: controller, onTap: () {}));
    await tester.pump();

    final start = tester.getCenter(find.byType(AnimatedScale));

    // One-pixel steps, like a real finger. A single big synthetic move would
    // resolve the gesture arena on release and hide the threshold entirely.
    final gesture = await tester.startGesture(tester.getCenter(find.byType(AnimatedScale)));
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(-1, -1));
      await tester.pump();
    }

    // Measured before lifting: this is what "does it feel responsive" means.
    final duringDrag = tester.getCenter(find.byType(AnimatedScale));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(duringDrag, isNot(start), reason: 'button should already be following after ~6px');
    expect(controller.offset, 0, reason: 'the list underneath must not scroll instead');
  });

  testWidgets('stays on screen when dragged far past the edges', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    await tester.drag(find.byType(AnimatedScale), const Offset(-5000, -5000));
    await tester.pumpAndSettle();

    final pos = tester.getCenter(find.byType(AnimatedScale));
    expect(pos.dx, greaterThanOrEqualTo(0));
    expect(pos.dy, greaterThanOrEqualTo(0));
  });

  testWidgets('tap still fires after a drag', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(onTap: () => taps++));
    await tester.pump();

    await tester.drag(find.byType(AnimatedScale), const Offset(-100, -100));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AnimatedScale));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('glow ring is hidden at rest and lit while dragging', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    Iterable<double> ringOpacities() =>
        tester.widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity)).map((w) => w.opacity);

    expect(ringOpacities().every((o) => o == 0), isTrue, reason: 'no glow at rest');

    final gesture = await tester.startGesture(tester.getCenter(find.byType(AnimatedScale)));
    for (var i = 0; i < 12; i++) {
      await gesture.moveBy(const Offset(-2, -2));
      await tester.pump();
    }

    expect(ringOpacities().every((o) => o == 1), isTrue, reason: 'both ring layers lit while dragging');

    await gesture.up();
    await tester.pumpAndSettle();

    expect(ringOpacities().every((o) => o == 0), isTrue, reason: 'glow fades out after release');
  });

  testWidgets('returns to its resting position after visiting another screen', (tester) async {
    await tester.pumpWidget(MaterialApp(
      navigatorObservers: [routeObserver],
      home: Scaffold(
        body: Stack(
          children: [
            Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        body: Builder(
                          builder: (c) => ElevatedButton(
                            onPressed: () => Navigator.of(c).pop(),
                            child: const Text('back'),
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('go'),
                ),
              ),
            ),
            const DraggableChatbotButton(),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final resting = tester.getCenter(find.byType(AnimatedScale));

    await tester.drag(find.byType(AnimatedScale), const Offset(-140, -200));
    await tester.pumpAndSettle();
    expect(tester.getCenter(find.byType(AnimatedScale)), isNot(resting));

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('back'));
    await tester.pumpAndSettle();

    expect(tester.getCenter(find.byType(AnimatedScale)), resting,
        reason: 'should be back in the bottom-right corner');
  });
}
