import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphnext/morphnext.dart';
import 'package:morphnext/src/rendering/morph_painter.dart';

import 'support/test_asset_bundle.dart';
import 'support/test_font_builder.dart';
import 'support/test_icons.dart';

void main() {
  testWidgets('controlled icon keeps one painter through both endpoints', (
    tester,
  ) async {
    final progress = AnimationController(vsync: tester, value: 0);
    addTearDown(progress.dispose);
    final bundle = fixtureBundle();
    await tester.pumpWidget(
      testHost(
        bundle,
        MorphIcon(
          from: testQuadraticIcon,
          to: testCompositeIcon,
          progress: progress,
        ),
      ),
    );
    expect(find.byIcon(testQuadraticIcon), findsOneWidget);
    expect(find.byType(CustomPaint), findsNothing);

    progress.value = 0.000001;
    await tester.pumpAndSettle();
    expect(find.byType(CustomPaint), findsOneWidget);

    progress.value = 0.999999;
    await tester.pump();
    expect(find.byType(CustomPaint), findsOneWidget);

    progress.value = 1;
    await tester.pump();
    expect(find.byIcon(testCompositeIcon), findsNothing);
    expect(find.byType(CustomPaint), findsOneWidget);

    progress.value = 0;
    await tester.pump();
    expect(find.byIcon(testQuadraticIcon), findsNothing);
    expect(find.byType(CustomPaint), findsOneWidget);
  });

  testWidgets('morph painter honors Icon size inside tight constraints', (
    tester,
  ) async {
    await tester.pumpWidget(
      testHost(
        fixtureBundle(),
        const SizedBox(
          width: 42,
          height: 38,
          child: MorphIcon(
            from: testQuadraticIcon,
            to: testCompositeIcon,
            progress: AlwaysStoppedAnimation<double>(0.5),
            size: 17,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final paint = find.byType(CustomPaint);
    expect(paint, findsOneWidget);
    expect(tester.getSize(paint), const Size.square(17));
    expect(tester.getCenter(paint), tester.getCenter(find.byType(MorphIcon)));
  });

  testWidgets('unsupported fonts switch native icons without crossfading', (
    tester,
  ) async {
    const systemIcon = IconData(0xe900, fontFamily: 'SystemOnly');
    final progress = AnimationController(vsync: tester);
    addTearDown(progress.dispose);
    await tester.pumpWidget(
      testHost(
        fixtureBundle(),
        MorphIcon(from: systemIcon, to: testCompositeIcon, progress: progress),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Icon), findsOneWidget);
    expect(find.byIcon(systemIcon), findsOneWidget);
    expect(find.byType(FadeTransition), findsNothing);

    progress.value = 1;
    await tester.pump();

    expect(find.byType(Icon), findsOneWidget);
    expect(find.byIcon(testCompositeIcon), findsOneWidget);
    expect(find.byType(FadeTransition), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('controlled progress outside its range keeps vector endpoints', (
    tester,
  ) async {
    final progress = AnimationController.unbounded(vsync: tester, value: -2);
    addTearDown(progress.dispose);
    await tester.pumpWidget(
      testHost(
        fixtureBundle(),
        MorphIcon(
          from: testQuadraticIcon,
          to: testCompositeIcon,
          progress: progress,
        ),
      ),
    );
    expect(find.byIcon(testQuadraticIcon), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byIcon(testQuadraticIcon), findsNothing);
    expect(find.byType(CustomPaint), findsOneWidget);

    progress.value = 0;
    await tester.pump();
    expect(find.byIcon(testQuadraticIcon), findsNothing);
    expect(find.byType(CustomPaint), findsOneWidget);

    progress.value = 2;
    await tester.pump();
    expect(find.byIcon(testCompositeIcon), findsNothing);
    expect(find.byType(CustomPaint), findsOneWidget);

    progress.value = 1;
    await tester.pump();
    expect(find.byIcon(testCompositeIcon), findsNothing);
    expect(find.byType(CustomPaint), findsOneWidget);
  });

  testWidgets('late plan results cannot replace a newer icon pair', (
    tester,
  ) async {
    const familyA = 'DelayedA';
    const familyB = 'ReadyB';
    const fromA = IconData(
      TestFontBuilder.quadraticCodePoint,
      fontFamily: familyA,
    );
    const toA = IconData(
      TestFontBuilder.compositeCodePoint,
      fontFamily: familyA,
    );
    const fromB = IconData(
      TestFontBuilder.quadraticCodePoint,
      fontFamily: familyB,
    );
    const toB = IconData(
      TestFontBuilder.compositeCodePoint,
      fontFamily: familyB,
    );
    final bundle = DelayedTestAssetBundle.fonts(
      manifest: <String, List<String>>{
        familyA: <String>['assets/a.ttf'],
        familyB: <String>['assets/b.ttf'],
      },
      assets: <String, Uint8List>{
        'assets/a.ttf': TestFontBuilder.trueType(),
        'assets/b.ttf': TestFontBuilder.trueType(),
      },
    )..delay('assets/a.ttf');

    await tester.pumpWidget(
      testHost(
        bundle,
        const MorphIcon(
          from: fromA,
          to: toA,
          progress: AlwaysStoppedAnimation<double>(0.5),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(
      testHost(
        bundle,
        const MorphIcon(
          from: fromB,
          to: toB,
          progress: AlwaysStoppedAnimation<double>(0.5),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final readyPainter = tester
        .widget<CustomPaint>(find.byType(CustomPaint))
        .painter;

    bundle.release('assets/a.ttf');
    await tester.pumpAndSettle();

    expect(
      identical(
        tester.widget<CustomPaint>(find.byType(CustomPaint)).painter,
        readyPainter,
      ),
      isTrue,
    );
  });

  testWidgets('IconTheme opacity and text scaling match ordinary Icon', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: fixtureBundle(),
        child: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: IconTheme(
              data: IconThemeData(
                size: 24,
                color: Color(0xcc336699),
                opacity: 0.5,
                applyTextScaling: true,
              ),
              child: Center(
                child: MorphIcon(
                  from: testQuadraticIcon,
                  to: testCompositeIcon,
                  progress: AlwaysStoppedAnimation<double>(0.5),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(MorphIcon)), const Size.square(36));
    expect(
      (tester.widget<CustomPaint>(find.byType(CustomPaint)).painter!
              as MorphPainter)
          .color
          .a,
      closeTo(0.4, 1e-6),
    );
  });

  testWidgets('semantic label creates one image node', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      testHost(
        fixtureBundle(),
        const MorphIcon(
          from: testQuadraticIcon,
          to: testCompositeIcon,
          progress: AlwaysStoppedAnimation<double>(0.5),
          semanticLabel: 'Morphing menu',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Morphing menu'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(MorphIcon)),
      matchesSemantics(label: 'Morphing menu', isImage: true),
    );
    semantics.dispose();
  });

  testWidgets(
    'unsupported axes are ignored by a static font without fallback',
    (tester) async {
      final bundle = fixtureBundle();
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: bundle,
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: IconTheme(
              data: IconThemeData(
                size: 24,
                color: Color(0xff123456),
                weight: 500,
              ),
              child: MorphIcon(
                from: testQuadraticIcon,
                to: testCompositeIcon,
                progress: AlwaysStoppedAnimation<double>(0.5),
              ),
            ),
          ),
        ),
      );
      for (var pump = 0; pump < 20; pump++) {
        await tester.pump();
      }

      expect(find.byType(CustomPaint), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
      expect(find.byType(FadeTransition), findsNothing);
      expect(bundle.loadCount('FontManifest.json'), 1);
    },
  );

  testWidgets(
    'a malformed font is reported once while fallback stays visible',
    (tester) async {
      const malformedFamily = 'MalformedWidgetFont';
      const malformedIcon = IconData(
        TestFontBuilder.quadraticCodePoint,
        fontFamily: malformedFamily,
      );
      final bundle = TestAssetBundle.fonts(
        manifest: <String, List<String>>{
          malformedFamily: <String>['assets/malformed.ttf'],
          testFontFamily: <String>['assets/ready.ttf'],
        },
        assets: <String, Uint8List>{
          'assets/malformed.ttf': TestFontBuilder.malformedTrueType(
            TrueTypeFault.decreasingEndpoints,
          ),
          'assets/ready.ttf': TestFontBuilder.trueType(),
        },
      );
      final reports = <FlutterErrorDetails>[];
      final previousHandler = FlutterError.onError;
      FlutterError.onError = reports.add;
      try {
        await tester.pumpWidget(
          testHost(
            bundle,
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                MorphIcon(
                  from: malformedIcon,
                  to: testCompositeIcon,
                  progress: AlwaysStoppedAnimation<double>(0.5),
                ),
                MorphIcon(
                  from: malformedIcon,
                  to: testCompositeIcon,
                  progress: AlwaysStoppedAnimation<double>(0.5),
                ),
              ],
            ),
          ),
        );
        for (var pump = 0; pump < 20; pump++) {
          await tester.pump();
        }
      } finally {
        FlutterError.onError = previousHandler;
      }

      expect(reports, hasLength(1));
      expect(reports.single.library, 'morphnext');
      expect(find.byType(Icon), findsNWidgets(2));
      expect(find.byType(FadeTransition), findsNothing);
    },
  );

  for (final invalidSize in <double>[-1, double.nan, double.infinity]) {
    testWidgets('invalid size $invalidSize follows Flutter debug assertions', (
      tester,
    ) async {
      await tester.pumpWidget(
        testHost(
          fixtureBundle(),
          MorphIcon(
            from: testQuadraticIcon,
            to: testCompositeIcon,
            progress: const AlwaysStoppedAnimation<double>(0),
            size: invalidSize,
          ),
        ),
      );

      expect(tester.takeException(), isA<AssertionError>());
    });
  }
}

Widget testHost(AssetBundle bundle, Widget child) => DefaultAssetBundle(
  bundle: bundle,
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: IconTheme(
      data: const IconThemeData(size: 24, color: Color(0xff123456)),
      child: Center(child: child),
    ),
  ),
);
