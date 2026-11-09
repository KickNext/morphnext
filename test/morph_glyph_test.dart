import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphnext/morphnext.dart';

import 'support/test_font_builder.dart';

const _tolerance = 1e-6;

Matcher _rect(double left, double top, double right, double bottom) =>
    isA<Rect>()
        .having((rect) => rect.left, 'left', closeTo(left, _tolerance))
        .having((rect) => rect.top, 'top', closeTo(top, _tolerance))
        .having((rect) => rect.right, 'right', closeTo(right, _tolerance))
        .having((rect) => rect.bottom, 'bottom', closeTo(bottom, _tolerance));

Rect _boundsOf(List<Float64List> polygons) {
  var left = double.infinity;
  var top = double.infinity;
  var right = double.negativeInfinity;
  var bottom = double.negativeInfinity;
  for (final points in polygons) {
    for (var i = 0; i < points.length; i += 2) {
      if (points[i] < left) left = points[i];
      if (points[i] > right) right = points[i];
      if (points[i + 1] < top) top = points[i + 1];
      if (points[i + 1] > bottom) bottom = points[i + 1];
    }
  }
  return Rect.fromLTRB(left, top, right, bottom);
}

void main() {
  final font = MorphFont.parse(TestFontBuilder.trueType());

  group('MorphFont', () {
    test('reads a glyph in ems about its pen position and baseline', () {
      // The test font has 1000 units per em, an 800 ascender and a -200
      // descender. The outer square spans 100..900 units on both axes.
      final glyph = font.glyph(TestFontBuilder.squareWithHoleCodePoint)!;
      expect(glyph.contourCount, 2);
      expect(glyph.bounds, _rect(.1, -.9, .9, -.1));
      expect(glyph.advance, 1);
      expect(glyph.ascender, .8);
      expect(glyph.descender, -.2);
    });

    test('reads CFF outlines in the same frame', () {
      final cff = MorphFont.parse(TestFontBuilder.cff1());
      final glyph = cff.glyph(TestFontBuilder.cffCodePoint)!;
      expect(glyph.contourCount, 2);
      expect(glyph.bounds, _rect(.1, -.9, .9, -.1));
    });

    test('selects variable font instances', () {
      final variable = MorphFont.parse(TestFontBuilder.variableTrueType());
      final regular = variable.glyph(TestFontBuilder.quadraticCodePoint)!;
      final heavy = variable.glyph(
        TestFontBuilder.quadraticCodePoint,
        weight: 900,
      )!;
      expect(regular.bounds.left, closeTo(0, _tolerance));
      expect(regular.bounds.right, closeTo(.3, _tolerance));
      expect(heavy.bounds.left, closeTo(.01, _tolerance));
      expect(heavy.bounds.right, closeTo(.34, _tolerance));
    });

    test('a missing or empty glyph is null', () {
      expect(font.contains(0x41), isFalse);
      expect(font.glyph(0x41), isNull);
      expect(font.contains(TestFontBuilder.emptyCodePoint), isTrue);
      expect(font.glyph(TestFontBuilder.emptyCodePoint), isNull);
    });

    test('rejects bytes that are not a font', () {
      expect(() => MorphFont.parse(Uint8List(16)), throwsFormatException);
    });
  });

  group('MorphOutline', () {
    test('placed scales about the origin, then moves', () {
      final glyph = font.glyph(TestFontBuilder.squareWithHoleCodePoint)!;
      final placed = glyph.placed(const Offset(2, 3), scale: 10);
      expect(placed, isNot(isA<MorphGlyph>()));
      expect(placed.contourCount, 2);
      expect(placed.bounds, _rect(3, -6, 11, 2));
    });

    test('placed rejects scales that are not positive and finite', () {
      final glyph = font.glyph(TestFontBuilder.chevronCodePoint)!;
      for (final scale in <double>[0, -1, double.nan, double.infinity]) {
        expect(
          () => glyph.placed(Offset.zero, scale: scale),
          throwsArgumentError,
        );
      }
      expect(
        () => glyph.placed(const Offset(double.nan, 0)),
        throwsArgumentError,
      );
    });

    test('combine draws several placed outlines as one', () {
      final square = font.glyph(TestFontBuilder.squareWithHoleCodePoint)!;
      final chevron = font.glyph(TestFontBuilder.chevronCodePoint)!;
      final word = MorphOutline.combine(<MorphOutline>[
        square.placed(Offset.zero),
        chevron.placed(Offset(square.advance, 0)),
      ])!;
      expect(word.contourCount, 3);
      expect(word.bounds, _rect(.1, -.9, 1.9, -.1));
      expect(MorphOutline.combine(const <MorphOutline>[]), isNull);
    });

    test('the README example morphs one word into another', () {
      final h = font.glyph(TestFontBuilder.squareWithHoleCodePoint)!;
      final i = font.glyph(TestFontBuilder.chevronCodePoint)!;
      final hi = MorphOutline.combine(<MorphOutline>[
        h.placed(Offset.zero, scale: 32),
        i.placed(Offset(h.advance * 32, 0), scale: 32),
      ])!;
      final ih = MorphOutline.combine(<MorphOutline>[
        i.placed(Offset.zero, scale: 32),
        h.placed(Offset(i.advance * 32, 0), scale: 32),
      ])!;
      final plan = MorphOutlinePlan(hi, ih);
      final output = plan.allocateOutput();
      plan.interpolate(.5, output);
      expect(output.every((points) => points.every((v) => v.isFinite)), isTrue);
    });
  });

  group('MorphOutlinePlan', () {
    test('pairs contours and starts and ends at its outlines', () {
      final from = font.glyph(TestFontBuilder.squareWithHoleCodePoint)!;
      final to = font.glyph(TestFontBuilder.diamondWithHoleCodePoint)!;
      final plan = MorphOutlinePlan(from, to);
      expect(plan.contourCount, 2);
      expect(plan.isOneToOne, isTrue);

      final output = plan.allocateOutput();
      expect(output, hasLength(2));
      plan.interpolate(0, output);
      expect(_boundsOf(output), _rect(.1, -.9, .9, -.1));
      plan.interpolate(1, output);
      expect(_boundsOf(output), _rect(.076, -.924, .924, -.076));
      plan.interpolate(.5, output);
      expect(output.every((points) => points.every((v) => v.isFinite)), isTrue);
    });

    test('a plan to an outline with fewer contours is not one to one', () {
      final from = font.glyph(TestFontBuilder.squareWithHoleCodePoint)!;
      final to = font.glyph(TestFontBuilder.chevronCodePoint)!;
      expect(to.contourCount, 1);
      expect(MorphOutlinePlan(from, to).isOneToOne, isFalse);
    });

    test('rejects output buffers it did not allocate', () {
      final glyph = font.glyph(TestFontBuilder.chevronCodePoint)!;
      final plan = MorphOutlinePlan(glyph, glyph);
      expect(() => plan.interpolate(.5, <Float64List>[]), throwsArgumentError);
      expect(
        () => plan.interpolate(double.nan, plan.allocateOutput()),
        throwsArgumentError,
      );
    });
  });
}
