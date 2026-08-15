import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphnext/morphnext.dart';
import 'package:morphnext/src/rendering/morph_painter.dart';

import 'support/test_asset_bundle.dart';
import 'support/test_font_builder.dart';
import 'support/test_icons.dart';

void main() {
  testWidgets('initial icon stays native without preparing morph geometry', (
    tester,
  ) async {
    final bundle = fixtureBundle();

    await tester.pumpWidget(
      testHost(bundle, const AnimatedMorphIcon(icon: testQuadraticIcon)),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.byIcon(testQuadraticIcon), findsOneWidget);
    expect(find.byType(CustomPaint), findsNothing);
    expect(bundle.loadCount('FontManifest.json'), 0);
  });

  testWidgets('update keeps the native-to-vector boundary continuous', (
    tester,
  ) async {
    await loadTestIconFonts();
    final bundle = fixtureBundle();
    const sampleKey = ValueKey<String>('sample');
    Widget sample(IconData icon) => testHost(
      bundle,
      RepaintBoundary(
        key: sampleKey,
        child: SizedBox.square(
          dimension: 64,
          child: AnimatedMorphIcon(icon: icon, size: 64),
        ),
      ),
    );

    await tester.pumpWidget(sample(testQuadraticIcon));
    expect(find.byIcon(testQuadraticIcon), findsOneWidget);
    expect(find.byType(CustomPaint), findsNothing);
    final sourceRaster = await inkRgba(tester, sampleKey);

    await tester.pumpWidget(sample(testCompositeIcon));
    await pumpUntilTransitionStart(tester);
    expect(currentPainter(tester).progress.value, 0);
    expectAlphaGeometryClose(
      await inkRgba(tester, sampleKey),
      sourceRaster,
      dimension: 64,
      reason: 'Starting the spring must not move the native endpoint.',
    );

    await tester.pump(const Duration(milliseconds: 1));
    expect(currentPainter(tester).progress.value, greaterThan(0));
    await tester.pumpAndSettle();
    expect(find.byType(CustomPaint), findsOneWidget);
    expect(currentPainter(tester).progress.value, 1);
    expect(find.byIcon(testCompositeIcon), findsNothing);
  });

  testWidgets('onEnd fires once after the vector endpoint settles', (
    tester,
  ) async {
    final bundle = fixtureBundle();
    var completions = 0;

    void handleEnd() => completions++;

    await tester.pumpWidget(
      testHost(
        bundle,
        AnimatedMorphIcon(icon: testQuadraticIcon, onEnd: handleEnd),
      ),
    );
    expect(find.byIcon(testQuadraticIcon), findsOneWidget);
    expect(find.byType(CustomPaint), findsNothing);
    expect(completions, 0);

    await tester.pumpWidget(
      testHost(
        bundle,
        AnimatedMorphIcon(icon: testCompositeIcon, onEnd: handleEnd),
      ),
    );
    await pumpUntilTransitionStart(tester);
    expect(completions, 0);

    await tester.pumpAndSettle();
    expect(completions, 1);
    expect(find.byType(CustomPaint), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(completions, 1);
  });

  testWidgets('settles subpixel-close and keeps the exact target raster', (
    tester,
  ) async {
    final bundle = fixtureBundle();
    await tester.pumpWidget(
      testHost(
        bundle,
        const AnimatedMorphIcon(icon: testQuadraticIcon, size: 720),
      ),
    );
    expect(find.byIcon(testQuadraticIcon), findsOneWidget);
    expect(find.byType(CustomPaint), findsNothing);
    await tester.pumpWidget(
      testHost(
        bundle,
        const AnimatedMorphIcon(icon: testCompositeIcon, size: 720),
      ),
    );
    await pumpUntilTransitionStart(tester);

    var paintedExactTarget = false;
    double? lastInexactProgress;
    for (var frame = 0; frame < 180; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      final progress = currentPainter(tester).progress.value;
      paintedExactTarget |= progress == 1;
      if (progress != 1) lastInexactProgress = progress;
      if (paintedExactTarget) break;
    }

    expect(
      paintedExactTarget,
      isTrue,
      reason: 'The residual spring offset must not snap to native Icon.',
    );
    expect(
      (lastInexactProgress! - 1).abs() * 720,
      lessThan(0.1),
      reason: 'The last spring frame must already be subpixel-close.',
    );
    await tester.pumpAndSettle();
    expect(find.byType(CustomPaint), findsOneWidget);
    expect(currentPainter(tester).progress.value, 1);
  });

  testWidgets('settled retarget starts from the exact cached endpoint', (
    tester,
  ) async {
    final bundle = fixtureBundle();
    await tester.pumpWidget(
      testHost(bundle, const AnimatedMorphIcon(icon: testQuadraticIcon)),
    );
    await tester.pumpWidget(
      testHost(bundle, const AnimatedMorphIcon(icon: testCompositeIcon)),
    );
    await pumpUntilTransitionStart(tester);
    await tester.pumpAndSettle();
    final settled = currentPainter(tester).debugOutput;

    await tester.pumpWidget(
      testHost(bundle, const AnimatedMorphIcon(icon: testCompressedIcon)),
    );
    await pumpUntilTransitionStart(tester);

    expectSamePointLists(currentPainter(tester).debugOutput, settled);
    await tester.pumpAndSettle();
  });

  testWidgets('rapid retarget keeps the visible geometry continuous', (
    tester,
  ) async {
    final bundle = fixtureBundle();
    var completions = 0;
    void handleEnd() => completions++;

    await tester.pumpWidget(
      testHost(
        bundle,
        AnimatedMorphIcon(icon: testQuadraticIcon, onEnd: handleEnd),
      ),
    );
    await tester.pumpWidget(
      testHost(
        bundle,
        AnimatedMorphIcon(icon: testCompositeIcon, onEnd: handleEnd),
      ),
    );
    await pumpUntilTransitionStart(tester);
    await tester.pump(const Duration(milliseconds: 70));
    final before = currentPainter(tester).debugOutput;

    await tester.pumpWidget(
      testHost(
        bundle,
        AnimatedMorphIcon(icon: testCompressedIcon, onEnd: handleEnd),
      ),
    );
    await tester.pump();

    expectPointListsClose(currentPainter(tester).debugOutput, before);
    expect(completions, 0);
    await tester.pumpAndSettle();
    expect(completions, 1);
  });

  testWidgets('interruption carries spring velocity into the new plan', (
    tester,
  ) async {
    final bundle = fixtureBundle();
    await tester.pumpWidget(
      testHost(bundle, const AnimatedMorphIcon(icon: testQuadraticIcon)),
    );
    await tester.pumpWidget(
      testHost(bundle, const AnimatedMorphIcon(icon: testCompositeIcon)),
    );
    await pumpUntilTransitionStart(tester);
    await tester.pump(const Duration(milliseconds: 40));
    final controller = currentPainter(tester).progress as AnimationController;
    final velocityBefore = controller.velocity;
    expect(velocityBefore, greaterThan(0));

    await tester.pumpWidget(
      testHost(bundle, const AnimatedMorphIcon(icon: testQuadraticIcon)),
    );
    await tester.pump();
    final restarted = currentPainter(tester).progress as AnimationController;
    expect(restarted.velocity, closeTo(velocityBefore.clamp(-14, 14), 1e-9));
    final valueBefore = restarted.value;

    await tester.pump(const Duration(milliseconds: 1));
    expect(restarted.value, greaterThan(valueBefore));
    await tester.pumpAndSettle();
  });

  testWidgets('custom underdamped spring overshoots with finite geometry', (
    tester,
  ) async {
    const underdamped = SpringDescription(mass: 1, stiffness: 300, damping: 14);
    final bundle = fixtureBundle();
    await tester.pumpWidget(
      testHost(
        bundle,
        const AnimatedMorphIcon(icon: testQuadraticIcon, spring: underdamped),
      ),
    );
    await tester.pumpWidget(
      testHost(
        bundle,
        const AnimatedMorphIcon(icon: testCompositeIcon, spring: underdamped),
      ),
    );
    await pumpUntilTransitionStart(tester);

    var overshot = false;
    for (
      var frame = 0;
      frame < 100 && find.byType(CustomPaint).evaluate().isNotEmpty;
      frame++
    ) {
      await tester.pump(const Duration(milliseconds: 5));
      if (find.byType(CustomPaint).evaluate().isEmpty) break;
      final painter = currentPainter(tester);
      overshot |= painter.progress.value > 1;
      expect(
        painter.debugOutput.expand((points) => points).every((v) => v.isFinite),
        isTrue,
      );
      if (overshot) break;
    }

    expect(overshot, isTrue);
    await tester.pumpAndSettle();
  });

  testWidgets('preserved velocity is capped during rapid retargeting', (
    tester,
  ) async {
    const fastSpring = SpringDescription(mass: 1, stiffness: 10000, damping: 1);
    final bundle = fixtureBundle();
    var icon = testQuadraticIcon;
    await tester.pumpWidget(
      testHost(bundle, AnimatedMorphIcon(icon: icon, spring: fastSpring)),
    );

    var observedUnboundedVelocity = false;
    for (var update = 0; update < 4; update++) {
      icon = icon == testQuadraticIcon ? testCompositeIcon : testQuadraticIcon;
      await tester.pumpWidget(
        testHost(bundle, AnimatedMorphIcon(icon: icon, spring: fastSpring)),
      );
      await pumpUntilTransitionStart(tester);
      final restarted = currentPainter(tester).progress as AnimationController;
      expect(restarted.velocity.abs(), lessThanOrEqualTo(14.000000001));
      await tester.pump(const Duration(milliseconds: 3));
      observedUnboundedVelocity |= restarted.velocity.abs() > 14;
    }

    expect(observedUnboundedVelocity, isTrue);
    await tester.pumpAndSettle();
  });

  testWidgets('late target cannot replace a newer transition', (tester) async {
    const delayedFamily = 'DelayedTarget';
    const readyFamily = 'ReadyTarget';
    const initial = IconData(
      TestFontBuilder.quadraticCodePoint,
      fontFamily: readyFamily,
    );
    const delayed = IconData(
      TestFontBuilder.compositeCodePoint,
      fontFamily: delayedFamily,
    );
    const ready = IconData(
      TestFontBuilder.compositeCodePoint,
      fontFamily: readyFamily,
    );
    final bundle = DelayedTestAssetBundle.fonts(
      manifest: <String, List<String>>{
        delayedFamily: <String>['assets/delayed.ttf'],
        readyFamily: <String>['assets/ready.ttf'],
      },
      assets: <String, Uint8List>{
        'assets/delayed.ttf': TestFontBuilder.trueType(),
        'assets/ready.ttf': TestFontBuilder.trueType(),
      },
    )..delay('assets/delayed.ttf');

    await tester.pumpWidget(
      testHost(bundle, const AnimatedMorphIcon(icon: initial)),
    );
    await tester.pumpWidget(
      testHost(bundle, const AnimatedMorphIcon(icon: delayed)),
    );
    await tester.pump();
    await tester.pumpWidget(
      testHost(bundle, const AnimatedMorphIcon(icon: ready)),
    );
    await pumpUntilTransitionStart(tester);
    await tester.pumpAndSettle();
    expect(find.byIcon(ready), findsNothing);
    expect(find.byType(CustomPaint), findsOneWidget);
    final readyOutput = currentPainter(tester).debugOutput;

    bundle.release('assets/delayed.ttf');
    await tester.pumpAndSettle();
    expect(find.byIcon(ready), findsNothing);
    expect(find.byType(CustomPaint), findsOneWidget);
    expectPointListsClose(currentPainter(tester).debugOutput, readyOutput);
  });

  testWidgets('pending font completion after dispose is harmless', (
    tester,
  ) async {
    const delayedFamily = 'DisposePending';
    const delayed = IconData(
      TestFontBuilder.compositeCodePoint,
      fontFamily: delayedFamily,
    );
    final bundle = DelayedTestAssetBundle.fonts(
      manifest: <String, List<String>>{
        testFontFamily: <String>['assets/ready.ttf'],
        delayedFamily: <String>['assets/delayed.ttf'],
      },
      assets: <String, Uint8List>{
        'assets/ready.ttf': TestFontBuilder.trueType(),
        'assets/delayed.ttf': TestFontBuilder.trueType(),
      },
    )..delay('assets/delayed.ttf');

    await tester.pumpWidget(
      testHost(bundle, const AnimatedMorphIcon(icon: testQuadraticIcon)),
    );
    await tester.pumpWidget(
      testHost(bundle, const AnimatedMorphIcon(icon: delayed)),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    bundle.release('assets/delayed.ttf');
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('disableAnimations settles updates without loading a font', (
    tester,
  ) async {
    final bundle = fixtureBundle();
    Widget reducedMotion(IconData icon) => DefaultAssetBundle(
      bundle: bundle,
      child: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: IconTheme(
            data: const IconThemeData(size: 24, color: Color(0xff123456)),
            child: Center(child: AnimatedMorphIcon(icon: icon)),
          ),
        ),
      ),
    );

    await tester.pumpWidget(reducedMotion(testQuadraticIcon));
    await tester.pumpWidget(reducedMotion(testCompositeIcon));
    await tester.pump();

    expect(find.byIcon(testCompositeIcon), findsOneWidget);
    expect(find.byType(CustomPaint), findsNothing);
    expect(bundle.loadCount('FontManifest.json'), 0);
  });

  testWidgets('semantic label is exposed as one image node', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      testHost(
        fixtureBundle(),
        const AnimatedMorphIcon(icon: testQuadraticIcon, semanticLabel: 'Menu'),
      ),
    );

    expect(find.bySemanticsLabel('Menu'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(AnimatedMorphIcon)),
      matchesSemantics(label: 'Menu', isImage: true),
    );
    semantics.dispose();
  });
}

MorphPainter currentPainter(WidgetTester tester) =>
    tester.widget<CustomPaint>(find.byType(CustomPaint)).painter!
        as MorphPainter;

Future<void> pumpUntilTransitionStart(WidgetTester tester) async {
  for (var pump = 0; pump < 40; pump++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
    await tester.pump();
    if (find.byType(CustomPaint).evaluate().isNotEmpty &&
        currentPainter(tester).progress.value < 1) {
      return;
    }
  }
  fail('Morph transition did not start');
}

Future<Uint8List> inkRgba(WidgetTester tester, Key key) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  return (await tester.runAsync<Uint8List>(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return Uint8List.fromList(
      data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  }))!;
}

void expectAlphaGeometryClose(
  Uint8List actual,
  Uint8List expected, {
  required int dimension,
  required String reason,
}) {
  expect(actual.length, expected.length, reason: reason);
  (double, double, double) centroid(Uint8List rgba) {
    var weightedX = 0.0;
    var weightedY = 0.0;
    var alphaTotal = 0.0;
    for (var y = 0; y < dimension; y++) {
      for (var x = 0; x < dimension; x++) {
        final alpha = rgba[4 * (y * dimension + x) + 3].toDouble();
        weightedX += x * alpha;
        weightedY += y * alpha;
        alphaTotal += alpha;
      }
    }
    return (weightedX / alphaTotal, weightedY / alphaTotal, alphaTotal);
  }

  final actualCentroid = centroid(actual);
  final expectedCentroid = centroid(expected);
  expect(actualCentroid.$1, closeTo(expectedCentroid.$1, 0.25), reason: reason);
  expect(actualCentroid.$2, closeTo(expectedCentroid.$2, 0.25), reason: reason);
}

void expectPointListsClose(
  List<Float64List> actual,
  List<Float64List> expected, {
  double tolerance = 1e-9,
}) {
  expect(actual.length, expected.length);
  for (var contour = 0; contour < actual.length; contour++) {
    final pointLength = actual[contour].length > expected[contour].length
        ? actual[contour].length
        : expected[contour].length;
    final actualPoints = subdivideToLength(actual[contour], pointLength);
    final expectedPoints = subdivideToLength(expected[contour], pointLength);
    for (var point = 0; point < pointLength; point++) {
      expect(actualPoints[point], closeTo(expectedPoints[point], tolerance));
    }
  }
}

void expectSamePointLists(
  List<Float64List> actual,
  List<Float64List> expected,
) {
  expect(actual.length, expected.length);
  for (var contour = 0; contour < actual.length; contour++) {
    final pointLength = actual[contour].length > expected[contour].length
        ? actual[contour].length
        : expected[contour].length;
    final actualPoints = subdivideToLength(actual[contour], pointLength);
    final expectedPoints = subdivideToLength(expected[contour], pointLength);
    Set<String> pointSet(Float64List points) => <String>{
      for (var index = 0; index < points.length; index += 2)
        '${points[index].toStringAsFixed(8)},'
            '${points[index + 1].toStringAsFixed(8)}',
    };
    expect(pointSet(actualPoints), pointSet(expectedPoints));
  }
}

Float64List subdivideToLength(Float64List source, int outputLength) {
  if (source.length == outputLength) return source;
  if (outputLength % source.length != 0) {
    throw StateError('Incompatible test contour cardinalities');
  }
  final factor = outputLength ~/ source.length;
  final pointCount = source.length ~/ 2;
  final output = Float64List(outputLength);
  var outputPoint = 0;
  for (var point = 0; point < pointCount; point++) {
    final next = point + 1 == pointCount ? 0 : point + 1;
    final x = source[2 * point];
    final y = source[2 * point + 1];
    final dx = source[2 * next] - x;
    final dy = source[2 * next + 1] - y;
    for (var step = 0; step < factor; step++) {
      final t = step / factor;
      output[2 * outputPoint] = x + dx * t;
      output[2 * outputPoint + 1] = y + dy * t;
      outputPoint++;
    }
  }
  return output;
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
