import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphnext/src/geometry/shape.dart';

void main() {
  test('builder lowers lines and quadratics to exact cubics', () {
    final builder = CubicContourBuilder()..moveTo(0, 0);
    builder.lineTo(3, 0);
    builder.quadraticTo(6, 0, 6, 3);
    final contour = builder.close();

    expect(
      contour.points.take(14),
      orderedEquals(<double>[0, 0, 1, 0, 2, 0, 3, 0, 5, 0, 6, 1, 6, 3]),
    );
    expect(contour.segmentCount, 3);
    expect(contour.points.every((value) => value.isFinite), isTrue);
  });

  test('cubic input is retained without sharing caller storage', () {
    final points = Float64List.fromList(<double>[0, 0, 1, 0, 1, 1, 0, 1]);
    final contour = CubicContour(points);
    points[0] = 99;

    expect(contour.points[0], 0);
    expect(contour.segmentCount, 1);
  });

  test('empty and non-finite contours are rejected', () {
    expect(() => CubicContourBuilder().close(), throwsFormatException);
    final builder = CubicContourBuilder()..moveTo(double.nan, 0);
    expect(() => builder.close(), throwsFormatException);
  });
}
