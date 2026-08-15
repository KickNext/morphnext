import 'dart:typed_data';

/// Fill semantics carried by an exact source outline.
enum MorphFillRule { nonZero, evenOdd }

/// A closed contour packed as one start point followed by cubic segments.
final class CubicContour {
  CubicContour(Float64List points) : points = Float64List.fromList(points) {
    if (points.length < 8 || (points.length - 2) % 6 != 0) {
      throw const FormatException('Invalid packed cubic contour');
    }
    if (!points.every((value) => value.isFinite)) {
      throw const FormatException('Non-finite cubic contour');
    }
  }

  /// Packed coordinates in `[p0, c1, c2, p1, ...]` order.
  final Float64List points;

  /// Number of cubic segments in this contour.
  int get segmentCount => (points.length - 2) ~/ 6;
}

/// Builds one closed [CubicContour] without temporary point objects.
final class CubicContourBuilder {
  final List<double> _points = <double>[];
  bool _closed = false;

  double get _x => _points[_points.length - 2];
  double get _y => _points[_points.length - 1];

  /// Starts the contour at (`x`, `y`).
  void moveTo(double x, double y) {
    if (_closed || _points.isNotEmpty) {
      throw StateError('A contour has exactly one move');
    }
    _points.addAll(<double>[x, y]);
  }

  /// Adds a straight segment represented exactly as a cubic.
  void lineTo(double x, double y) {
    _requireActive();
    final x0 = _x;
    final y0 = _y;
    cubicTo(
      x0 + (x - x0) / 3,
      y0 + (y - y0) / 3,
      x0 + 2 * (x - x0) / 3,
      y0 + 2 * (y - y0) / 3,
      x,
      y,
    );
  }

  /// Elevates a quadratic segment exactly to a cubic.
  void quadraticTo(double controlX, double controlY, double x, double y) {
    _requireActive();
    final x0 = _x;
    final y0 = _y;
    cubicTo(
      x0 + 2 * (controlX - x0) / 3,
      y0 + 2 * (controlY - y0) / 3,
      x + 2 * (controlX - x) / 3,
      y + 2 * (controlY - y) / 3,
      x,
      y,
    );
  }

  /// Adds a cubic segment.
  void cubicTo(
    double control1X,
    double control1Y,
    double control2X,
    double control2Y,
    double x,
    double y,
  ) {
    _requireActive();
    _points.addAll(<double>[control1X, control1Y, control2X, control2Y, x, y]);
  }

  /// Closes and returns the contour.
  CubicContour close() {
    _requireActive();
    if (_points.length < 8) {
      throw const FormatException('A contour needs at least one segment');
    }
    if (!_points.every((value) => value.isFinite)) {
      throw const FormatException('Non-finite cubic contour');
    }
    final startX = _points[0];
    final startY = _points[1];
    if (_x != startX || _y != startY) {
      lineTo(startX, startY);
    }
    _closed = true;
    return CubicContour(Float64List.fromList(_points));
  }

  void _requireActive() {
    if (_closed) {
      throw StateError('Contour is already closed');
    }
    if (_points.isEmpty) {
      throw const FormatException('Contour has no start point');
    }
  }
}

/// A fixed-cardinality sampled contour with filled-shape topology.
final class SampledContour {
  SampledContour(
    Float64List points, {
    required this.signedArea,
    required this.depth,
    required this.parent,
    bool? isHole,
  }) : points = Float64List.fromList(points),
       _isHole = isHole ?? depth.isOdd {
    if (points.length < 2 || points.length.isOdd) {
      throw const FormatException('Invalid sampled contour');
    }
    if (!points.every((value) => value.isFinite) || !signedArea.isFinite) {
      throw const FormatException('Non-finite sampled contour');
    }
    if (depth < 0) {
      throw const FormatException('Negative contour depth');
    }
  }

  /// Alternating x/y coordinates.
  final Float64List points;

  /// Signed polygon area in shape coordinates.
  final double signedArea;

  /// Number of containing contours.
  final int depth;

  /// Index of the nearest containing contour, if any.
  final int? parent;

  final bool _isHole;

  /// Whether this contour cuts a hole from its parent.
  bool get isHole => _isHole;
}

/// A list of sampled contours forming one filled icon.
final class MorphShape {
  MorphShape(
    List<SampledContour> contours, {
    List<CubicContour>? exactContours,
    this.fillRule = MorphFillRule.evenOdd,
  }) : contours = List<SampledContour>.unmodifiable(contours),
       exactContours = exactContours == null
           ? null
           : List<CubicContour>.unmodifiable(<CubicContour>[
               for (final contour in exactContours)
                 CubicContour(contour.points),
             ]);

  /// Contours in deterministic topology order.
  final List<SampledContour> contours;

  /// Original cubic contours, when this shape came from vector outlines.
  final List<CubicContour>? exactContours;

  /// Fill rule used by the original exact outline.
  final MorphFillRule fillRule;
}
