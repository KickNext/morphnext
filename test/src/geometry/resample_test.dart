import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphnext/src/geometry/resample.dart';
import 'package:morphnext/src/geometry/shape.dart';

void main() {
  test('closed square keeps every corner as an exact sample', () {
    final points = resampleContour(squareContour(0, 0, 1), pointCount: 8);

    for (final corner in <(double, double)>[(0, 0), (1, 0), (1, 1), (0, 1)]) {
      expect(pointPairs(points), contains(corner));
    }
    expect(points.length, 16);
  });

  test('circle-like cubic samples are approximately equidistant', () {
    const kappa = 0.5522847498307936;
    final circle = CubicContourBuilder()..moveTo(1, 0);
    circle.cubicTo(1, kappa, kappa, 1, 0, 1);
    circle.cubicTo(-kappa, 1, -1, kappa, -1, 0);
    circle.cubicTo(-1, -kappa, -kappa, -1, 0, -1);
    circle.cubicTo(kappa, -1, 1, -kappa, 1, 0);

    final points = resampleContour(circle.close(), pointCount: 32);
    final lengths = <double>[
      for (var i = 0; i < 32; i++)
        math.sqrt(
          math.pow(points[2 * ((i + 1) % 32)] - points[2 * i], 2) +
              math.pow(points[2 * ((i + 1) % 32) + 1] - points[2 * i + 1], 2),
        ),
    ];
    for (var i = 0; i < 8; i++) {
      expect(lengths[i + 8], closeTo(lengths[i], 1e-12));
      expect(lengths[i + 16], closeTo(lengths[i], 1e-12));
      expect(lengths[i + 24], closeTo(lengths[i], 1e-12));
    }
    expect(
      lengths.reduce(math.max) / lengths.reduce(math.min),
      lessThan(1.001),
    );
  });

  test('zero-length contour stays finite with fixed cardinality', () {
    final dot = CubicContourBuilder()
      ..moveTo(2, 3)
      ..lineTo(2, 3);
    final points = resampleContour(dot.close());

    expect(points.length, 128);
    expect(points.every((value) => value.isFinite), isTrue);
    expect(points.toSet(), <double>{2, 3});
  });

  test('containment assigns outer fill, hole, and nested fill', () {
    final shape = sampleContours(<CubicContour>[
      squareContour(0, 0, 10),
      squareContour(2, 2, 6),
      squareContour(4, 4, 2),
    ]);

    expect(shape.contours.map((contour) => contour.depth), <int>[0, 1, 2]);
    expect(shape.contours.map((contour) => contour.parent), <int?>[null, 0, 1]);
    expect(shape.contours.map((contour) => contour.isHole), <bool>[
      false,
      true,
      false,
    ]);
  });

  test('topology order is independent of input order', () {
    final outer = squareContour(0, 0, 10);
    final hole = squareContour(2, 2, 6);
    final island = squareContour(4, 4, 2);

    final first = sampleContours(<CubicContour>[outer, hole, island]);
    final second = sampleContours(<CubicContour>[island, outer, hole]);

    expect(
      second.contours.map((contour) => contour.depth),
      first.contours.map((contour) => contour.depth),
    );
    for (var i = 0; i < first.contours.length; i++) {
      expect(
        second.contours[i].points,
        orderedEquals(first.contours[i].points),
      );
      expect(second.contours[i].parent, first.contours[i].parent);
    }
  });

  test('point buffers can be retopologized without aliasing', () {
    final outer = resampleContour(squareContour(0, 0, 10));
    final hole = resampleContour(squareContour(2, 2, 6));
    final shape = sampledShapeFromPointBuffers(<Float64List>[hole, outer]);
    outer[0] = 99;

    expect(shape.contours.map((contour) => contour.depth), <int>[0, 1]);
    expect(shape.contours.first.points[0], 0);
  });

  test('point buffers retain independent contour cardinalities', () {
    final outer = resampleContour(squareContour(0, 0, 10), pointCount: 128);
    final hole = resampleContour(squareContour(2, 2, 6), pointCount: 32);

    final shape = sampledShapeFromPointBuffers(<Float64List>[hole, outer]);

    expect(shape.contours.map((contour) => contour.depth), <int>[0, 1]);
    expect(shape.contours.map((contour) => contour.points.length), <int>[
      256,
      64,
    ]);
  });

  test('fixed-seed generated contours stay finite and deterministic', () {
    final random = math.Random(0x4d4f5250);
    for (var sample = 0; sample < 100; sample++) {
      final count = 5 + random.nextInt(7);
      final vertices = <(double, double)>[];
      final builder = CubicContourBuilder();
      for (var i = 0; i < count; i++) {
        final angle = 2 * math.pi * i / count;
        final radius = (i.isEven ? 1.0 : 0.55) + random.nextDouble() * 0.1;
        final point = (radius * math.cos(angle), radius * math.sin(angle));
        vertices.add(point);
        if (i == 0) {
          builder.moveTo(point.$1, point.$2);
        } else {
          builder.lineTo(point.$1, point.$2);
        }
      }
      final contour = builder.close();
      final first = resampleContour(contour);
      final second = resampleContour(contour);

      expect(first.length, 128);
      expect(first.every((value) => value.isFinite), isTrue);
      expect(second, orderedEquals(first));
      for (var i = 0; i < vertices.length; i++) {
        if (_turnAngle(vertices, i) > math.pi / 8) {
          expect(pointPairs(first), contains(vertices[i]));
        }
      }
    }
  });
}

List<(double, double)> pointPairs(Float64List points) => <(double, double)>[
  for (var i = 0; i < points.length; i += 2) (points[i], points[i + 1]),
];

CubicContour squareContour(double left, double top, double size) {
  final builder = CubicContourBuilder()
    ..moveTo(left, top)
    ..lineTo(left + size, top)
    ..lineTo(left + size, top + size)
    ..lineTo(left, top + size);
  return builder.close();
}

double _turnAngle(List<(double, double)> points, int index) {
  final previous = points[(index - 1) % points.length];
  final current = points[index];
  final next = points[(index + 1) % points.length];
  final incomingX = current.$1 - previous.$1;
  final incomingY = current.$2 - previous.$2;
  final outgoingX = next.$1 - current.$1;
  final outgoingY = next.$2 - current.$2;
  return math
      .atan2(
        incomingX * outgoingY - incomingY * outgoingX,
        incomingX * outgoingX + incomingY * outgoingY,
      )
      .abs();
}
