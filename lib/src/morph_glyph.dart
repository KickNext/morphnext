import 'dart:typed_data';
import 'dart:ui' show Offset, Rect;

import 'font/open_type_font.dart';
import 'geometry/morph_plan.dart';
import 'geometry/resample.dart';
import 'geometry/shape.dart';

/// A font file's glyph outlines, for morphing glyphs outside `MorphIcon`, such
/// as text, custom painters, or glyphs placed by the caller.
///
/// `MorphIcon` reads a glyph from a bundled icon font and fits it into an icon
/// box. [MorphFont] reads the same outlines without the box. Each glyph comes
/// back in ems, about its own pen position and baseline, so the caller can
/// place it where a text layout puts it, [MorphOutline.combine] glyphs into a
/// word, and morph with [MorphOutlinePlan].
///
/// Nothing is cached. Keep the fonts, glyphs, and plans you reuse.
///
/// This API is experimental. It may change in a minor release before 1.0.
final class MorphFont {
  MorphFont._(this._font);

  /// Parses an OpenType font with TrueType (`glyf`, including variable fonts)
  /// or CFF outlines.
  ///
  /// Throws a [FormatException] if [bytes] is not a font morphnext can read.
  /// Font collections (`.ttc`) and CFF2 outlines are not supported.
  factory MorphFont.parse(Uint8List bytes) =>
      MorphFont._(OpenTypeFont.parse(bytes));

  final OpenTypeFont _font;

  /// The tags of the design axes a variable font declares, such as `wght` and
  /// `opsz`. Empty for a static font.
  ///
  /// [glyph] can select an instance along `wght`, `FILL`, `GRAD`, and `opsz`.
  /// Other axes stay at their defaults.
  late final Set<String> axes = Set<String>.unmodifiable(
    _font.variationAxes.keys,
  );

  /// Whether the font maps [codePoint] to a glyph.
  bool contains(int codePoint) => _font.containsCodePoint(codePoint);

  /// The outline and metrics of [codePoint], or null when the font lacks it or
  /// its glyph draws nothing (a space).
  ///
  /// [weight], [fill], [grade], and [opticalSize] select an instance of a
  /// variable TrueType font through its `wght`, `FILL`, `GRAD`, and `opsz`
  /// axes, as `MorphIcon`'s parameters of the same names do. Fonts without
  /// those axes ignore them.
  ///
  /// Throws a [FormatException] if the glyph's data is malformed.
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
    final unitsPerEm = metrics.unitsPerEm.toDouble();
    if (outline.contours.isEmpty) return null;
    final contours = <CubicContour>[
      for (final contour in outline.contours)
        CubicContour(
          Float64List.fromList(<double>[
            for (var i = 0; i < contour.points.length; i += 2) ...<double>[
              contour.points[i] / unitsPerEm,
              -contour.points[i + 1] / unitsPerEm,
            ],
          ]),
        ),
    ];
    // Sampling orients the contours so that every glyph's fill winds the same
    // way whatever its font's convention, and glyphs that overlap after
    // [MorphOutline.combine] add up instead of cancelling.
    return MorphGlyph._(
      sampleOutlineContours(contours),
      advance: outline.advanceWidth / unitsPerEm,
      ascender: metrics.ascender / unitsPerEm,
      descender: metrics.descender / unitsPerEm,
    );
  }
}

/// A filled outline that [MorphOutlinePlan] can morph. It is either a
/// [MorphGlyph] or several outlines placed as one with [combine].
///
/// Coordinates are in ems, with y pointing down. For a glyph, x runs right from
/// the pen position and the baseline is at y = 0, so glyphs from different
/// fonts share one frame. Fill the outline with the non-zero rule.
///
/// This API is experimental. It may change in a minor release before 1.0.
final class MorphOutline {
  MorphOutline._(this._shape);

  /// Several outlines as one, so that a whole word, for example, morphs as a
  /// single outline instead of letter by letter.
  ///
  /// Place each part first with [placed]. Each part keeps the points it was
  /// sampled at. Returns null when [parts] is empty.
  static MorphOutline? combine(Iterable<MorphOutline> parts) {
    final shapes = <MorphShape>[for (final part in parts) part._shape];
    if (shapes.isEmpty) return null;
    return MorphOutline._(
      sampledShapeFromPointBuffers(
        <Float64List>[
          for (final shape in shapes)
            for (final contour in shape.contours) contour.points,
        ],
        fillRule: MorphFillRule.nonZero,
        exactContours: <CubicContour>[
          for (final shape in shapes) ...shape.exactContours!,
        ],
      ),
    );
  }

  /// The sampled outline, with each glyph's fill winding the same way, and
  /// the exact contours it was sampled from. [placed] and [combine] move these
  /// points instead of sampling again, which could start a contour elsewhere
  /// and change how it morphs.
  final MorphShape _shape;

  /// This outline scaled about its origin by [scale], then moved by [offset].
  ///
  /// For a glyph, [scale] is usually the font size and [offset] is the pen
  /// position on the baseline.
  MorphOutline placed(Offset offset, {double scale = 1}) {
    if (!offset.isFinite) {
      throw ArgumentError.value(offset, 'offset', 'Must be finite');
    }
    if (!scale.isFinite || scale <= 0) {
      throw ArgumentError.value(scale, 'scale', 'Must be finite and positive');
    }
    Float64List move(Float64List points) {
      final moved = Float64List(points.length);
      for (var i = 0; i < points.length; i += 2) {
        moved[i] = offset.dx + points[i] * scale;
        moved[i + 1] = offset.dy + points[i + 1] * scale;
      }
      return moved;
    }

    // A positive scale keeps each contour's direction, nesting, and order.
    return MorphOutline._(
      MorphShape(
        <SampledContour>[
          for (final contour in _shape.contours)
            SampledContour(
              move(contour.points),
              signedArea: contour.signedArea * scale * scale,
              depth: contour.depth,
              parent: contour.parent,
              isHole: contour.isHole,
            ),
        ],
        exactContours: <CubicContour>[
          for (final contour in _shape.exactContours!)
            CubicContour(move(contour.points)),
        ],
        fillRule: _shape.fillRule,
      ),
    );
  }

  /// How many closed contours the outline has.
  int get contourCount => _shape.contours.length;

  /// The smallest rectangle that contains the sampled outline.
  Rect get bounds {
    var left = double.infinity;
    var top = double.infinity;
    var right = double.negativeInfinity;
    var bottom = double.negativeInfinity;
    for (final contour in _shape.contours) {
      final points = contour.points;
      for (var i = 0; i < points.length; i += 2) {
        final x = points[i];
        final y = points[i + 1];
        if (x < left) left = x;
        if (x > right) right = x;
        if (y < top) top = y;
        if (y > bottom) bottom = y;
      }
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }
}

/// One glyph's outline and metrics, from [MorphFont.glyph].
///
/// The outline is in ems, about the glyph's pen position and baseline, as
/// [MorphOutline] describes. Its metrics are in ems too.
///
/// This API is experimental. It may change in a minor release before 1.0.
final class MorphGlyph extends MorphOutline {
  MorphGlyph._(
    super.shape, {
    required this.advance,
    required this.ascender,
    required this.descender,
  }) : super._();

  /// How far the pen moves after this glyph.
  final double advance;

  /// The font's ascender, above the baseline. The ascender line is at
  /// y = -[ascender].
  final double ascender;

  /// The font's descender, negative below the baseline. The descender line is
  /// at y = -[descender].
  final double descender;
}

/// The morph from one [MorphOutline] to another. Contours are paired as
/// `MorphIcon` pairs an icon's contours.
///
/// Planning is the expensive step. Keep a plan and call [interpolate] for each
/// frame, which allocates nothing.
///
/// This API is experimental. It may change in a minor release before 1.0.
final class MorphOutlinePlan {
  /// Plans the morph from [from] to [to].
  MorphOutlinePlan(MorphOutline from, MorphOutline to)
    : _plan = buildMorphPlan(from._shape, to._shape);

  final MorphPlan _plan;

  /// How many contour pairs the morph draws.
  int get contourCount => _plan.items.length;

  /// Whether each contour of one outline paired with exactly one contour of
  /// the other, so that no contour grows from a point or shrinks to one.
  bool get isOneToOne => _plan.items.every(
    (item) => !item.sourceCollapsed && !item.targetCollapsed,
  );

  /// Allocates one output buffer per contour pair, for [interpolate].
  List<Float64List> allocateOutput() => _plan.allocateOutput();

  /// Writes the outline at [t] into [output], which must come from
  /// [allocateOutput].
  ///
  /// [t] is 0 at `from` and 1 at `to`. Values up to 0.25 past either end
  /// extrapolate, as a spring overshoots, and values further out are clamped.
  /// Each buffer holds one closed polygon as interleaved x, y in the outlines'
  /// coordinates. Fill them together with the non-zero rule.
  void interpolate(double t, List<Float64List> output) =>
      _plan.interpolate(t, output);
}
