import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphnext/src/geometry/morph_plan.dart';
import 'package:morphnext/src/geometry/shape.dart';

void main() {
  test('polar plan is exact at both endpoints', () {
    final source = irregularLoop();
    final target = transformContour(
      source,
      angle: math.pi / 2,
      translateX: 3,
      translateY: 4,
    );
    final plan = buildMorphPlan(singleShape(source), singleShape(target));
    final output = plan.allocateOutput();

    plan.interpolate(0, output);
    expectPointsClose(output.single, source.points);
    plan.interpolate(1, output);
    expectPointsClose(output.single, target.points);
    expect(plan.items.single.theta, closeTo(math.pi / 2, 1e-10));
  });

  test('closed correspondence checks reversal and every circular offset', () {
    final source = irregularLoop();
    final target = reindexContour(source, offset: 17, reversed: true);
    final plan = buildMorphPlan(singleShape(source), singleShape(target));

    expect(plan.items.single.residual, lessThan(1e-10));
    expect(plan.items.single.theta.abs(), lessThan(1e-10));
    plan.interpolate(0.5, plan.allocateOutput());
  });

  test('non-zero target winding survives correspondence alignment', () {
    final source = irregularLoop();
    final target = reindexContour(source, offset: 17, reversed: true);
    final plan = buildMorphPlan(
      MorphShape(<SampledContour>[source], fillRule: MorphFillRule.nonZero),
      MorphShape(<SampledContour>[target], fillRule: MorphFillRule.nonZero),
    );
    final output = plan.allocateOutput();

    plan.interpolate(1, output);

    expect(signedArea(output.single), closeTo(target.signedArea, 1e-9));
  });

  test(
    'degenerate similarity stays inside the endpoint envelope both ways',
    () {
      final clockwise = irregularLoop();
      final counterClockwise = reindexContour(
        clockwise,
        offset: 17,
        reversed: true,
      );
      for (final pair in <(SampledContour, SampledContour)>[
        (clockwise, counterClockwise),
        (counterClockwise, clockwise),
      ]) {
        final plan = buildMorphPlan(
          MorphShape(<SampledContour>[
            pair.$1,
          ], fillRule: MorphFillRule.nonZero),
          MorphShape(<SampledContour>[
            pair.$2,
          ], fillRule: MorphFillRule.nonZero),
        );
        final output = plan.allocateOutput();

        for (final progress in <double>[0.1, 0.25, 0.5, 0.75, 0.9]) {
          plan.interpolate(progress, output);
          expect(
            maximumAbsoluteCoordinate(output.single),
            lessThan(1.5),
            reason: 'progress $progress',
          );
        }
      }
    },
  );

  test('high-quality tiny similarity keeps scale and rotation', () {
    final source = irregularLoop();
    final target = transformContour(source, angle: 0.7, scale: 0.01);
    final plan = buildMorphPlan(singleShape(source), singleShape(target));

    expect(plan.items.single.residual, lessThan(1e-6));
    expect(plan.items.single.theta, closeTo(0.7, 1e-10));
    expect(math.exp(plan.items.single.logScale), closeTo(0.01, 1e-10));
  });

  test('holes match holes and a new hole grows from its parent centroid', () {
    final plan = buildMorphPlan(diskShapeWithHoles(1), diskShapeWithHoles(2));
    expect(plan.items, hasLength(3));
    final growing = plan.items.singleWhere((item) => item.sourceCollapsed);
    expect(growing.targetCollapsed, isFalse);

    final output = plan.allocateOutput();
    plan.interpolate(0, output);
    final growingIndex = plan.items.indexOf(growing);
    expect(uniquePointCount(output[growingIndex]), 1);
    plan.interpolate(0.5, output);
    expect(
      output.expand((points) => points).every((value) => value.isFinite),
      isTrue,
    );
    plan.interpolate(1, output);
    expect(uniquePointCount(output[growingIndex]), greaterThan(1));
  });

  test('removed contours shrink instead of duplicating filled geometry', () {
    final plan = buildMorphPlan(diskShapeWithHoles(2), diskShapeWithHoles(0));
    expect(plan.items.where((item) => item.targetCollapsed), hasLength(2));
    final output = plan.allocateOutput();
    plan.interpolate(1, output);
    for (var i = 0; i < plan.items.length; i++) {
      if (plan.items[i].targetCollapsed) {
        expect(uniquePointCount(output[i]), 1);
      }
    }
  });

  test('snapshot is position-continuous when replanned', () {
    final first = buildMorphPlan(
      singleShape(irregularLoop()),
      singleShape(transformContour(irregularLoop(), angle: 0.8, translateX: 2)),
    );
    final visible = first.snapshot(0.43);
    final second = buildMorphPlan(
      visible,
      singleShape(
        transformContour(irregularLoop(), angle: -0.4, translateY: 3),
      ),
    );
    final output = second.allocateOutput();
    second.interpolate(0, output);

    expectSamePointSet(output.single, visible.contours.single.points);
  });

  test('matched contour pairs negotiate independent cardinalities', () {
    final source = MorphShape(<SampledContour>[
      circleContour(0, 0, 10, 0, null, pointCount: 128),
      reindexContour(
        circleContour(0, 0, 2, 1, 0, pointCount: 32),
        offset: 0,
        reversed: true,
      ),
    ]);
    final target = MorphShape(<SampledContour>[
      circleContour(0, 0, 9, 0, null, pointCount: 64),
      reindexContour(
        circleContour(0, 0, 3, 1, 0, pointCount: 64),
        offset: 0,
        reversed: true,
      ),
    ]);

    final plan = buildMorphPlan(source, target);

    expect(plan.items.map((item) => item.source.length), <int>[256, 128]);
    for (final item in plan.items) {
      expect(item.targetInSourceFrame.length, item.source.length);
      expect(item.orientedTarget.length, item.source.length);
    }

    final visible = plan.snapshot(0.4);
    expect(visible.contours.map((contour) => contour.points.length), <int>[
      256,
      128,
    ]);
    final replanned = buildMorphPlan(visible, target);
    expect(replanned.items.map((item) => item.source.length), <int>[256, 128]);
    expect(
      replanned
          .interpolatedCopy(0.25)
          .expand((points) => points)
          .every((value) => value.isFinite),
      isTrue,
    );
  });

  test('global rigid pass transports variable contours as one block', () {
    final first = transformContour(irregularLoop(radius: 0.35), translateX: -2);
    final second = transformContour(
      irregularLoop(radius: 0.45, pointCount: 32),
      translateX: 2,
    );
    final source = MorphShape(<SampledContour>[first, second]);
    final target = MorphShape(<SampledContour>[
      transformContour(first, angle: math.pi / 2),
      transformContour(second, angle: math.pi / 2),
    ]);
    final plan = buildMorphPlan(source, target);
    final output = plan.allocateOutput();
    plan.interpolate(0.5, output);

    expect(plan.items.every((item) => item.blockOffset != null), isTrue);
    expect(
      distance(centroid(output[0]), centroid(output[1])),
      closeTo(4, 1e-8),
    );
  });

  test('empty shapes and incompatible output buffers are rejected', () {
    expect(
      () => buildMorphPlan(
        MorphShape(const <SampledContour>[]),
        singleShape(irregularLoop()),
      ),
      throwsFormatException,
    );
    final plan = buildMorphPlan(
      singleShape(irregularLoop()),
      singleShape(irregularLoop()),
    );
    expect(
      () => plan.interpolate(0.5, const <Float64List>[]),
      throwsArgumentError,
    );
  });

  test(
    'fixed-seed plans remain deterministic and finite through overshoot',
    () {
      final random = math.Random(0x504c414e);
      for (var i = 0; i < 100; i++) {
        final source = irregularLoop(radius: 0.5 + random.nextDouble());
        final target = transformContour(
          source,
          angle: -math.pi + 2 * math.pi * random.nextDouble(),
          scale: 0.3 + 2 * random.nextDouble(),
          translateX: -2 + 4 * random.nextDouble(),
          translateY: -2 + 4 * random.nextDouble(),
        );
        final first = buildMorphPlan(singleShape(source), singleShape(target));
        final second = buildMorphPlan(singleShape(source), singleShape(target));
        final firstOutput = first.allocateOutput();
        final secondOutput = second.allocateOutput();
        for (final t in <double>[0, 0.25, 0.5, 1, 1.2]) {
          first.interpolate(t, firstOutput);
          second.interpolate(t, secondOutput);
          expect(firstOutput.single.every((value) => value.isFinite), isTrue);
          expect(secondOutput.single, orderedEquals(firstOutput.single));
        }
      }
    },
  );
}

MorphShape singleShape(SampledContour contour) =>
    MorphShape(<SampledContour>[contour]);

SampledContour irregularLoop({double radius = 1, int pointCount = 64}) {
  final points = Float64List(2 * pointCount);
  for (var i = 0; i < pointCount; i++) {
    final angle = 2 * math.pi * i / pointCount;
    final localRadius =
        radius * (1 + 0.18 * math.cos(3 * angle) + 0.07 * math.sin(5 * angle));
    points[2 * i] = localRadius * math.cos(angle);
    points[2 * i + 1] = localRadius * math.sin(angle);
  }
  return sampledContour(points);
}

SampledContour circleContour(
  double centerX,
  double centerY,
  double radius,
  int depth,
  int? parent, {
  int pointCount = 64,
}) {
  final points = Float64List(2 * pointCount);
  for (var i = 0; i < pointCount; i++) {
    final angle = 2 * math.pi * i / pointCount;
    points[2 * i] = centerX + radius * math.cos(angle);
    points[2 * i + 1] = centerY + radius * math.sin(angle);
  }
  return sampledContour(points, depth: depth, parent: parent);
}

MorphShape diskShapeWithHoles(int holeCount) => MorphShape(<SampledContour>[
  circleContour(0, 0, 10, 0, null),
  if (holeCount >= 1) circleContour(-3, 0, 1, 1, 0),
  if (holeCount >= 2) circleContour(3, 0, 1, 1, 0),
]);

SampledContour transformContour(
  SampledContour source, {
  double angle = 0,
  double scale = 1,
  double translateX = 0,
  double translateY = 0,
}) {
  final cosine = math.cos(angle) * scale;
  final sine = math.sin(angle) * scale;
  final points = Float64List(source.points.length);
  for (var i = 0; i < source.points.length; i += 2) {
    final x = source.points[i];
    final y = source.points[i + 1];
    points[i] = translateX + x * cosine - y * sine;
    points[i + 1] = translateY + x * sine + y * cosine;
  }
  return sampledContour(points, depth: source.depth, parent: source.parent);
}

SampledContour reindexContour(
  SampledContour source, {
  required int offset,
  required bool reversed,
}) {
  final pointCount = source.points.length ~/ 2;
  final points = Float64List(source.points.length);
  for (var i = 0; i < pointCount; i++) {
    final walked = reversed ? pointCount - 1 - i : i;
    final sourceIndex = (walked + offset) % pointCount;
    points[2 * i] = source.points[2 * sourceIndex];
    points[2 * i + 1] = source.points[2 * sourceIndex + 1];
  }
  return sampledContour(points, depth: source.depth, parent: source.parent);
}

SampledContour sampledContour(
  Float64List points, {
  int depth = 0,
  int? parent,
}) => SampledContour(
  points,
  signedArea: signedArea(points),
  depth: depth,
  parent: parent,
);

double signedArea(Float64List points) {
  var area = 0.0;
  final count = points.length ~/ 2;
  for (var i = 0; i < count; i++) {
    final next = (i + 1) % count;
    area +=
        points[2 * i] * points[2 * next + 1] -
        points[2 * next] * points[2 * i + 1];
  }
  return area / 2;
}

void expectPointsClose(
  Float64List actual,
  Float64List expected, {
  double tolerance = 1e-9,
}) {
  expect(actual.length, expected.length);
  for (var i = 0; i < actual.length; i++) {
    expect(actual[i], closeTo(expected[i], tolerance), reason: 'coordinate $i');
  }
}

void expectSamePointSet(Float64List actual, Float64List expected) {
  final actualPoints = <String>{
    for (var i = 0; i < actual.length; i += 2)
      '${actual[i].toStringAsFixed(9)},${actual[i + 1].toStringAsFixed(9)}',
  };
  final expectedPoints = <String>{
    for (var i = 0; i < expected.length; i += 2)
      '${expected[i].toStringAsFixed(9)},${expected[i + 1].toStringAsFixed(9)}',
  };
  expect(actualPoints, expectedPoints);
}

int uniquePointCount(Float64List points) => <(double, double)>{
  for (var i = 0; i < points.length; i += 2) (points[i], points[i + 1]),
}.length;

double maximumAbsoluteCoordinate(Float64List points) => points.fold<double>(
  0,
  (maximum, coordinate) => math.max(maximum, coordinate.abs()),
);

(double, double) centroid(Float64List points) {
  var x = 0.0;
  var y = 0.0;
  for (var i = 0; i < points.length; i += 2) {
    x += points[i];
    y += points[i + 1];
  }
  final count = points.length ~/ 2;
  return (x / count, y / count);
}

double distance((double, double) a, (double, double) b) =>
    math.sqrt(math.pow(a.$1 - b.$1, 2) + math.pow(a.$2 - b.$2, 2));
