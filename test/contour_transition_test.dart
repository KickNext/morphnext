import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphnext/morphnext.dart';
import 'package:morphnext/src/font/font_selection.dart';
import 'package:morphnext/src/morph_repository.dart';
import 'package:morphnext/src/rendering/morph_painter.dart';

import 'animated_morph_icon_test.dart'
    show pumpUntilTransitionStart, currentPainter, expectPointListsClose;
import 'morph_icon_test.dart' show testHost;
import 'support/test_icons.dart';
import 'support/test_asset_bundle.dart';
import 'support/test_font_builder.dart';

void main() {
  setUp(MorphCache.reset);
  tearDown(MorphCache.reset);

  testWidgets('pending legacy result cannot replace the newly selected mode', (
    tester,
  ) async {
    final bundle = DelayedTestAssetBundle.fonts(
      manifest: {
        testFontFamily: ['icons.ttf'],
      },
      assets: {'icons.ttf': TestFontBuilder.trueType()},
    )..delay('icons.ttf');
    await tester.pumpWidget(
      testHost(bundle, const AnimatedMorphIcon(icon: testSquareWithHoleIcon)),
    );
    await tester.pumpWidget(
      testHost(bundle, const AnimatedMorphIcon(icon: testCompositeIcon)),
    );
    await tester.pump();
    await tester.pumpWidget(
      testHost(
        bundle,
        const AnimatedMorphIcon(
          icon: testCompositeIcon,
          contourTransition: MorphContourTransition.linear,
        ),
      ),
    );
    bundle.release('icons.ttf');
    await pumpUntilTransitionStart(tester);
    expect(
      currentPainter(tester).plan.contourTransition,
      MorphContourTransition.linear,
    );
    await tester.pumpAndSettle();
    final settled = currentPainter(tester).plan;
    await tester.pumpWidget(
      testHost(bundle, const AnimatedMorphIcon(icon: testCompositeIcon)),
    );
    await tester.pumpAndSettle();
    // An idle policy change only affects the next transition. It does not
    // replace the settled vector frame with a differently rasterized Icon.
    expect(identical(currentPainter(tester).plan, settled), isTrue);
  });

  test('cache separates modes and reuses each mode', () async {
    final repository = MorphRepository.forBundle(fixtureBundle());
    final legacy = await repository.planFor(
      testSquareWithHoleIcon,
      testCompositeIcon,
      TextDirection.ltr,
    );
    final linear = await repository.planFor(
      testSquareWithHoleIcon,
      testCompositeIcon,
      TextDirection.ltr,
      defaultMorphFontSelection,
      MorphContourTransition.linear,
    );
    expect(identical(legacy, linear), isFalse);
    expect(legacy.contourTransition, MorphContourTransition.legacy);
    expect(linear.contourTransition, MorphContourTransition.linear);
    expect(MorphCache.currentMorphs, 2);
    expect(
      identical(
        linear,
        await repository.planFor(
          testSquareWithHoleIcon,
          testCompositeIcon,
          TextDirection.ltr,
          defaultMorphFontSelection,
          MorphContourTransition.linear,
        ),
      ),
      isTrue,
    );
  });

  testWidgets('precache and controlled widget use the selected mode', (
    tester,
  ) async {
    final bundle = fixtureBundle();
    late BuildContext context;
    await tester.pumpWidget(
      testHost(
        bundle,
        Builder(
          builder: (value) {
            context = value;
            return const SizedBox();
          },
        ),
      ),
    );
    final ready = precacheMorph(
      context,
      from: testSquareWithHoleIcon,
      to: testCompositeIcon,
      bidirectional: true,
      contourTransition: MorphContourTransition.linear,
    );
    await tester.pumpAndSettle();
    await ready;
    expect(MorphCache.currentMorphs, 2);
    for (final mode in [
      MorphContourTransition.linear,
      MorphContourTransition.legacy,
    ]) {
      await tester.pumpWidget(
        testHost(
          bundle,
          MorphIcon(
            from: testSquareWithHoleIcon,
            to: testCompositeIcon,
            progress: const AlwaysStoppedAnimation(0.25),
            contourTransition: mode,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final painter =
          tester.widget<CustomPaint>(find.byType(CustomPaint)).painter
              as MorphPainter;
      expect(painter.plan.contourTransition, mode);
      expect(
        MorphCache.currentMorphs,
        mode == MorphContourTransition.linear ? 2 : 3,
      );
    }
  });

  testWidgets('changing mode during a spring preserves the visible shape', (
    tester,
  ) async {
    final bundle = fixtureBundle();
    var completed = 0;
    await tester.pumpWidget(
      testHost(bundle, const AnimatedMorphIcon(icon: testSquareWithHoleIcon)),
    );
    await tester.pumpWidget(
      testHost(
        bundle,
        AnimatedMorphIcon(icon: testCompositeIcon, onEnd: () => completed++),
      ),
    );
    await pumpUntilTransitionStart(tester);
    await tester.pump(const Duration(milliseconds: 35));
    final before = currentPainter(tester).debugOutput;
    await tester.pumpWidget(
      testHost(
        bundle,
        AnimatedMorphIcon(
          icon: testCompositeIcon,
          contourTransition: MorphContourTransition.linear,
          onEnd: () => completed++,
        ),
      ),
    );
    await tester.pump();
    expect(
      currentPainter(tester).plan.contourTransition,
      MorphContourTransition.linear,
    );
    expectPointListsClose(currentPainter(tester).debugOutput, before);
    expect(completed, 0);
    await tester.pump(const Duration(milliseconds: 20));
    final second = currentPainter(tester).debugOutput;
    await tester.pumpWidget(
      testHost(
        bundle,
        AnimatedMorphIcon(
          icon: testSquareWithHoleIcon,
          contourTransition: MorphContourTransition.linear,
          onEnd: () => completed++,
        ),
      ),
    );
    await tester.pump();
    expectPointListsClose(currentPainter(tester).debugOutput, second);
    await tester.pumpAndSettle();
    expect(completed, 1);
  });

  testWidgets('linear mode still respects reduced motion', (tester) async {
    final bundle = fixtureBundle();
    Widget host(IconData icon) => testHost(
      bundle,
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: AnimatedMorphIcon(
          icon: icon,
          contourTransition: MorphContourTransition.linear,
        ),
      ),
    );
    await tester.pumpWidget(host(testSquareWithHoleIcon));
    await tester.pumpWidget(host(testCompositeIcon));
    await tester.pumpAndSettle();
    expect(find.byIcon(testCompositeIcon), findsOneWidget);
    expect(bundle.loadCount('FontManifest.json'), 0);
  });
}
