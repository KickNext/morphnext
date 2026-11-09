import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphnext/morphnext.dart';

import 'support/test_font_builder.dart';

void main() {
  final font = MorphFont.parse(TestFontBuilder.trueType());

  test('reads a glyph in ems about its origin', () {
    final glyph = font.glyph(TestFontBuilder.squareWithHoleCodePoint)!;
    expect(glyph.contourCount, 2);
    expect(glyph.advance, greaterThan(0));
    expect(glyph.ascender, greaterThan(0));
    expect(glyph.descender, lessThanOrEqualTo(0));
  });

  test('a missing or empty glyph is null', () {
    expect(font.contains(0x41), isFalse);
    expect(font.glyph(0x41), isNull);
    expect(font.glyph(TestFontBuilder.emptyCodePoint), isNull);
  });

  test('a plan between two glyphs pairs their contours', () {
    final a = font.glyph(TestFontBuilder.squareWithHoleCodePoint)!;
    final b = font.glyph(TestFontBuilder.diamondWithHoleCodePoint)!;
    final plan = MorphGlyphPlan(a, b);
    expect(plan.contourCount, 2);
    expect(plan.isOneToOne, isTrue);

    final out = plan.allocateOutput();
    for (final t in <double>[0, .5, 1]) {
      plan.interpolate(t, out);
      expect(out, hasLength(2));
      expect(out.every((points) => points.every((v) => v.isFinite)), isTrue);
    }
  });

  test('a plan to a glyph with fewer contours is not one to one', () {
    final a = font.glyph(TestFontBuilder.squareWithHoleCodePoint)!;
    final b = font.glyph(TestFontBuilder.chevronCodePoint)!;
    expect(b.contourCount, 1);
    expect(MorphGlyphPlan(a, b).isOneToOne, isFalse);
  });

  test('rejects bytes that are not a font', () {
    expect(() => MorphFont.parse(Uint8List(16)), throwsFormatException);
  });
}
