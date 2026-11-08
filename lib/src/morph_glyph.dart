import 'dart:typed_data';

import 'font/open_type_font.dart';
import 'geometry/morph_plan.dart';
import 'geometry/resample.dart';
import 'geometry/shape.dart';
import 'morph_repository.dart' show contourPointCountFor;

/// A font file's outlines, for morphing glyphs outside `MorphIcon`: text,
/// custom painters, or icons placed by the caller.
///
/// `MorphIcon` reads a glyph from a bundled icon font and places it in an
/// icon box. This is the same outline reader without the box: glyphs come
/// back in ems about their own origin, so the caller can place them (for
/// example at the pen positions a `TextPainter` laid out).
final class MorphFont {
  MorphFont._(this._font);

  /// Parses an OpenType font file (TrueType `glyf` or CFF outlines).
  ///
  /// Throws a [FormatException] if [bytes] isn't a font morphnext can read.
  factory MorphFont.parse(Uint8List bytes) =>
      MorphFont._(OpenTypeFont.parse(bytes));

  final OpenTypeFont _font;

  /// Whether the font maps [codePoint] to a glyph.
  bool contains(int codePoint) => _font.containsCodePoint(codePoint);

  /// The outline of [codePoint], or null when the font lacks it or its glyph
  /// has no contours (a space).
  ///
  /// The variable-font axes select an instance when the font declares them,
  /// as `MorphIcon`'s parameters of the same names do.
  MorphGlyph? glyph(
    int codePoint, {
    double? weight,
    double? fill,
    double? grade,
    double? opticalSize,
  }) {
    if (!_font.containsCodePoint(codePoint)) return null;
    final outline = _font.glyphForCodePoint(codePoint, (
      fill: fill,
      weight: weight,
      grade: grade,
      opticalSize: opticalSize,
    ));
    final metrics = outline.metrics;
    final upm = metrics.unitsPerEm.toDouble();
    if (upm <= 0 || outline.contours.isEmpty) return null;
    final contours = <CubicContour>[
      for (final contour in outline.contours)
        CubicContour(
          Float64List.fromList(<double>[
            for (var i = 0; i < contour.points.length; i += 2) ...<double>[
              contour.points[i] / upm,
              (metrics.ascender - contour.points[i + 1]) / upm,
            ],
          ]),
        ),
    ];
    final shape = sampleContoursWithPointCounts(
      contours,
      pointCounts: <int>[for (final c in contours) contourPointCountFor(c)],
      fillRule: MorphFillRule.nonZero,
    );
    if (shape.contours.isEmpty) return null;
    return MorphGlyph._(
      shape,
      advance: outline.advanceWidth / upm,
      ascender: metrics.ascender / upm,
      descender: metrics.descender / upm,
    );
  }
}

/// One glyph's outline, sampled for morphing.
///
/// Coordinates are in ems: x to the right of the glyph's origin, y down
/// from the font's [ascender] (so the baseline is at y = [ascender]).
final class MorphGlyph {
  MorphGlyph._(
    this._shape, {
    required this.advance,
    required this.ascender,
    required this.descender,
  });

  final MorphShape _shape;

  /// The glyph's advance width, in ems.
  final double advance;

  /// The font's ascender, in ems above the baseline.
  final double ascender;

  /// The font's descender, in ems (negative below the baseline).
  final double descender;

  /// How many closed contours the outline has.
  int get contourCount => _shape.contours.length;
}

/// The morph from one [MorphGlyph] to another, paired contour by contour as
/// `MorphIcon` pairs icons.
final class MorphGlyphPlan {
  MorphGlyphPlan._(this._plan);

  /// Plans the morph from [from] to [to].
  factory MorphGlyphPlan(MorphGlyph from, MorphGlyph to) =>
      MorphGlyphPlan._(buildMorphPlan(from._shape, to._shape));

  final MorphPlan _plan;

  /// How many contour pairs the morph draws.
  int get contourCount => _plan.items.length;

  /// Whether every contour of each glyph paired with exactly one contour of
  /// the other, so no contour grows from or shrinks to a point.
  bool get isOneToOne => _plan.items.every(
    (item) => !item.sourceCollapsed && !item.targetCollapsed,
  );

  /// Allocates one output buffer per contour pair, for [interpolate].
  List<Float64List> allocateOutput() => _plan.allocateOutput();

  /// Writes the outline at [t] (0 is `from`, 1 is `to`) into [output]: one
  /// closed polygon per contour pair, interleaved x, y in the glyphs' ems.
  /// Fill it with the non-zero rule.
  void interpolate(double t, List<Float64List> output) =>
      _plan.interpolate(t, output);
}
