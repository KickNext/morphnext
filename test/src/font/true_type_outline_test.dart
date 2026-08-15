import 'package:flutter_test/flutter_test.dart';
import 'package:morphnext/src/font/binary_reader.dart';
import 'package:morphnext/src/font/open_type_font.dart';
import 'package:morphnext/src/geometry/shape.dart';

import '../../support/test_font_builder.dart';

void main() {
  test('gvar applies a requested TrueType variation instance', () {
    final font = OpenTypeFont.parse(TestFontBuilder.variableTrueType());
    final base = font.glyphForCodePoint(TestFontBuilder.quadraticCodePoint);
    final varied = font.glyphForCodePoint(
      TestFontBuilder.quadraticCodePoint,
      const (
        fill: null,
        weight: 650,
        grade: null,
        opticalSize: null,
        fontWeight: null,
      ),
    );

    expect(font.variationAxes.keys, contains('wght'));
    expect(
      varied.contours.single.points.first,
      base.contours.single.points.first + 5,
    );
    expect(varied.advanceWidth, base.advanceWidth + 5);
  });

  test('gvar adjusts variable composite component placement', () {
    final font = OpenTypeFont.parse(
      TestFontBuilder.variableCompositeTrueType(),
    );
    final base = font.glyphForCodePoint(TestFontBuilder.compositeCodePoint);
    final varied = font.glyphForCodePoint(
      TestFontBuilder.compositeCodePoint,
      const (
        fill: null,
        weight: 650.0,
        grade: null,
        opticalSize: null,
        fontWeight: null,
      ),
    );

    expect(cubicBounds(varied.contours).$1, cubicBounds(base.contours).$1 + 10);
  });

  test(
    'simple glyph inserts implied points and elevates quadratics exactly',
    () {
      final font = OpenTypeFont.parse(TestFontBuilder.trueType());
      final glyph = font.glyphForCodePoint(TestFontBuilder.quadraticCodePoint);

      expect(glyph.contours, hasLength(1));
      final points = glyph.contours.single.points;
      expect(points[0], 0);
      expect(points[1], 0);
      expect(points[2], closeTo(200 / 3, 1e-12));
      expect(points[3], closeTo(400 / 3, 1e-12));
      expect(points[6], 150);
      expect(points[7], 200);
      expect(points[12], 300);
      expect(points[13], 0);
      expect(glyph.advanceWidth, 1000);
    },
  );

  test('nested composite transforms are flattened', () {
    final font = OpenTypeFont.parse(TestFontBuilder.trueType());
    final composite = font.glyphForCodePoint(
      TestFontBuilder.compositeCodePoint,
    );
    final nested = font.glyphForCodePoint(
      TestFontBuilder.nestedCompositeCodePoint,
    );

    expect(cubicBounds(composite.contours), (100, 200, 600, 700));
    expect(cubicBounds(nested.contours), (110, 220, 610, 720));
  });

  test('point attachment aligns component points', () {
    final glyph = OpenTypeFont.parse(
      TestFontBuilder.trueType(),
    ).glyphForCodePoint(TestFontBuilder.attachedCompositeCodePoint);

    expect(glyph.contours, hasLength(2));
    expect(cubicBounds(glyph.contours), (0, 0, 2000, 1000));
  });

  test('compressed coordinate flags and empty glyphs decode', () {
    final font = OpenTypeFont.parse(TestFontBuilder.trueType());

    expect(
      cubicBounds(
        font.glyphForCodePoint(TestFontBuilder.compressedCodePoint).contours,
      ),
      (0, -400, 400, 30),
    );
    expect(
      font.glyphForCodePoint(TestFontBuilder.emptyCodePoint).contours,
      isEmpty,
    );
  });

  test('composite argument widths, transforms, and instructions decode', () {
    final font = OpenTypeFont.parse(TestFontBuilder.trueType());

    expect(
      cubicBounds(
        font.glyphForCodePoint(TestFontBuilder.byteCompositeCodePoint).contours,
      ),
      (10, -20, 1010, 980),
    );
    expect(
      cubicBounds(
        font.glyphForCodePoint(TestFontBuilder.xyScaleCodePoint).contours,
      ),
      (0, 0, 500, 250),
    );
    expect(
      cubicBounds(
        font.glyphForCodePoint(TestFontBuilder.matrixCodePoint).contours,
      ),
      (-1000, 0, 0, 1000),
    );
    expect(
      cubicBounds(
        font
            .glyphForCodePoint(TestFontBuilder.instructedCompositeCodePoint)
            .contours,
      ),
      (0, 0, 1000, 1000),
    );
    expect(
      cubicBounds(
        font.glyphForCodePoint(TestFontBuilder.scaledOffsetCodePoint).contours,
      ),
      (51, 0, 551, 500),
    );
    expect(
      font
          .glyphForCodePoint(TestFontBuilder.metricsCompositeCodePoint)
          .advanceWidth,
      800,
    );
  });

  test('long loca offsets decode', () {
    final glyph = OpenTypeFont.parse(
      TestFontBuilder.trueType(longLoca: true),
    ).glyphForCodePoint(TestFontBuilder.quadraticCodePoint);

    expect(glyph.contours, hasLength(1));
  });

  test('composite cycles and truncated coordinates are typed failures', () {
    expect(
      () => OpenTypeFont.parse(
        TestFontBuilder.trueType(compositeCycle: true),
      ).glyphForCodePoint(TestFontBuilder.compositeCodePoint),
      throwsA(isA<FontDataException>()),
    );
    expect(
      () => OpenTypeFont.parse(
        TestFontBuilder.trueType(truncatedCoordinates: true),
      ).glyphForCodePoint(TestFontBuilder.quadraticCodePoint),
      throwsA(isA<FontDataException>()),
    );
  });

  test('malformed locations, limits, flags, and references are typed', () {
    for (final fault in TrueTypeFault.values) {
      expect(
        () {
          final font = OpenTypeFont.parse(
            TestFontBuilder.malformedTrueType(fault),
          );
          font.glyphForCodePoint(TestFontBuilder.quadraticCodePoint);
        },
        throwsA(isA<FontDataException>()),
        reason: fault.name,
      );
    }
  });
}

(double, double, double, double) cubicBounds(List<CubicContour> contours) {
  var left = double.infinity;
  var top = double.infinity;
  var right = double.negativeInfinity;
  var bottom = double.negativeInfinity;
  for (final contour in contours) {
    final points = contour.points;
    for (var i = 0; i < points.length; i += 2) {
      left = left < points[i] ? left : points[i];
      top = top < points[i + 1] ? top : points[i + 1];
      right = right > points[i] ? right : points[i];
      bottom = bottom > points[i + 1] ? bottom : points[i + 1];
    }
  }
  return (left, top, right, bottom);
}
