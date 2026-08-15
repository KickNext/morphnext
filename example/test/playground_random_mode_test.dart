import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphnext/morphnext.dart';
import 'package:morphnext_example/main.dart';

void main() {
  final previewFinder = find.byWidgetPredicate(
    (widget) =>
        widget is AnimatedMorphIcon &&
        widget.semanticLabel == 'Primary morph preview',
  );

  Future<void> armRandom(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MorphnextExampleApp(
        initialLocation: '/playground',
        loadLiveMetadata: false,
        useGoogleFonts: false,
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('random-mode')));
    await tester.pumpAndSettle();
  }

  IconData previewIcon(WidgetTester tester) =>
      tester.widget<AnimatedMorphIcon>(previewFinder).icon;

  testWidgets('rolling a target animates instead of swapping the icon', (
    tester,
  ) async {
    await armRandom(tester);
    final shuffle = find.byKey(const ValueKey<String>('shuffle-icon'));

    // The morph state has to survive a roll. If the preview were re-keyed per
    // endpoint the element would be replaced and the glyph would simply cut to
    // the next shape, which is the whole thing this package exists to avoid.
    final elementBefore = tester.element(previewFinder);
    final iconBefore = previewIcon(tester);

    await tester.tap(shuffle);
    await tester.pump();

    expect(previewIcon(tester), isNot(iconBefore));
    expect(identical(tester.element(previewFinder), elementBefore), isTrue);

    // A transition takes many frames to settle; a straight swap would settle
    // almost immediately.
    final frames = await tester.pumpAndSettle();
    expect(frames, greaterThan(5));
  });

  testWidgets('auto rolling advances on its interval and cancels on disarm', (
    tester,
  ) async {
    await armRandom(tester);
    await tester.tap(find.byKey(const ValueKey<String>('shuffle-auto')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('shuffle-interval')),
      findsOneWidget,
    );

    final seen = <IconData>{previewIcon(tester)};
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 1400));
      seen.add(previewIcon(tester));
    }
    expect(seen.length, greaterThan(2));

    // Disarming has to cancel the periodic timer, or the pending-timer check
    // at teardown fails.
    await tester.tap(find.byKey(const ValueKey<String>('random-mode')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('random controls never move the code block', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MorphnextExampleApp(
        initialLocation: '/playground',
        loadLiveMetadata: false,
        useGoogleFonts: false,
      ),
    );
    await tester.pump();

    final code = find.byKey(const ValueKey<String>('playground-code'));
    final initialTop = tester.getTopLeft(code).dy;

    await tester.tap(find.byKey(const ValueKey<String>('random-mode')));
    await tester.pump();
    expect(tester.getTopLeft(code).dy, initialTop);

    await tester.tap(find.byKey(const ValueKey<String>('shuffle-auto')));
    await tester.pump();
    expect(tester.getTopLeft(code).dy, initialTop);

    await tester.tap(find.byKey(const ValueKey<String>('random-mode')));
    await tester.pump();
    expect(tester.getTopLeft(code).dy, initialTop);
    expect(
      tester
          .widget<Switch>(find.byKey(const ValueKey<String>('shuffle-auto')))
          .value,
      isFalse,
    );
    await tester.pump(const Duration(seconds: 4));
  });
}
