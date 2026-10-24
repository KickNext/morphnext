import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphnext/morphnext.dart';
import 'package:morphnext/src/morph_repository.dart';
import 'package:morphnext/src/rendering/morph_painter.dart';

import 'morph_icon_test.dart' show testHost;
import 'support/test_asset_bundle.dart';
import 'support/test_font_builder.dart';
import 'support/test_icons.dart';

void main() {
  setUp(MorphCache.reset);
  tearDown(MorphCache.reset);
  testWidgets('precache shares themed forward and reverse plans with widgets', (
    tester,
  ) async {
    final bundle = fixtureBundle();
    late BuildContext context;
    await tester.pumpWidget(
      testHost(
        bundle,
        IconTheme(
          data: const IconThemeData(color: Color(0xff000000), weight: 650),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Builder(
              builder: (value) {
                context = value;
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
    final first = precacheMorph(
      context,
      from: testQuadraticIcon,
      to: testCompositeIcon,
      bidirectional: true,
    );
    final second = precacheMorph(
      context,
      from: testQuadraticIcon,
      to: testCompositeIcon,
      bidirectional: true,
    );
    await tester.pumpAndSettle();
    await Future.wait(<Future<void>>[first, second]);
    expect(bundle.loadCount('assets/icons.ttf'), 1);
    expect(MorphCache.currentMorphs, 2);
    expect(MorphCache.currentBytes, greaterThan(0));
    final theme = IconTheme.of(context);
    final selection = (
      fill: theme.fill,
      weight: theme.weight,
      grade: theme.grade,
      opticalSize: theme.opticalSize,
      fontWeight: null,
    );
    final repository = MorphRepository.forBundle(bundle);
    final forward = await repository.planFor(
      testQuadraticIcon,
      testCompositeIcon,
      TextDirection.rtl,
      selection,
    );
    final reverse = await repository.planFor(
      testCompositeIcon,
      testQuadraticIcon,
      TextDirection.rtl,
      selection,
    );
    for (final entry in [
      (testQuadraticIcon, testCompositeIcon, forward),
      (testCompositeIcon, testQuadraticIcon, reverse),
    ]) {
      await tester.pumpWidget(
        testHost(
          bundle,
          MorphIcon(
            from: entry.$1,
            to: entry.$2,
            weight: 650,
            textDirection: TextDirection.rtl,
            progress: const AlwaysStoppedAnimation(0.5),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final painter =
          tester.widget<CustomPaint>(find.byType(CustomPaint)).painter
              as MorphPainter;
      expect(identical(painter.plan, entry.$3), isTrue);
    }
  });

  testWidgets('precache obeys global limits, clear and disable', (
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
    Future<void> prepare() async {
      final pending = precacheMorph(
        context,
        from: testQuadraticIcon,
        to: testCompositeIcon,
        bidirectional: true,
      );
      await tester.pumpAndSettle();
      await pending;
    }

    MorphCache.configure(maxMorphs: 1, maxBytes: 1 << 20);
    await prepare();
    expect(MorphCache.currentMorphs, 1);
    MorphCache.clear();
    expect(MorphCache.currentMorphs, 0);
    await prepare();
    expect(MorphCache.currentMorphs, 1);
    MorphCache.disable();
    await prepare();
    expect(MorphCache.currentMorphs, 0);
    expect(MorphCache.currentBytes, 0);
    MorphCache.configure(maxMorphs: 2, maxBytes: 1);
    await prepare();
    expect(MorphCache.currentMorphs, 0);
  });

  testWidgets('clearing during precache prevents late cache repopulation', (
    tester,
  ) async {
    final bundle = DelayedTestAssetBundle.fonts(
      manifest: {
        testFontFamily: ['icons.ttf'],
      },
      assets: {'icons.ttf': TestFontBuilder.trueType()},
    )..delay('icons.ttf');
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
    final pending = precacheMorph(
      context,
      from: testQuadraticIcon,
      to: testCompositeIcon,
      bidirectional: true,
    );
    await tester.pump();
    MorphCache.clear();
    bundle.release('icons.ttf');
    await tester.pumpAndSettle();
    await pending;
    expect(MorphCache.currentMorphs, 0);
    final retry = precacheMorph(
      context,
      from: testQuadraticIcon,
      to: testCompositeIcon,
      bidirectional: true,
    );
    await tester.pumpAndSettle();
    await retry;
    expect(MorphCache.currentMorphs, 2);
  });

  testWidgets(
    'precache errors are awaitable and transient failures can retry',
    (tester) async {
      final bundle = fixtureBundle()..failNext('assets/icons.ttf');
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
      final failed = expectLater(
        precacheMorph(context, from: testQuadraticIcon, to: testCompositeIcon),
        throwsFormatException,
      );
      await tester.pumpAndSettle();
      await failed;
      final retried = precacheMorph(
        context,
        from: testQuadraticIcon,
        to: testCompositeIcon,
      );
      await tester.pumpAndSettle();
      await retried;
      expect(bundle.loadCount('assets/icons.ttf'), 2);
    },
  );

  testWidgets('equal icons do not load fonts and context may unmount', (
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
    await precacheMorph(
      context,
      from: testQuadraticIcon,
      to: testQuadraticIcon,
    );
    expect(bundle.loadCount('FontManifest.json'), 0);
    final pending = precacheMorph(
      context,
      from: testQuadraticIcon,
      to: testCompositeIcon,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await pending;
    expect(tester.takeException(), isNull);
  });
}
