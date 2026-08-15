import 'dart:typed_data';

import '../geometry/shape.dart';
import 'binary_reader.dart';
import 'glyph_variations.dart';
import 'open_type_font.dart';

const _onCurve = 0x01;
const _xShort = 0x02;
const _yShort = 0x04;
const _repeat = 0x08;
const _xSameOrPositive = 0x10;
const _ySameOrPositive = 0x20;

const _argsAreWords = 0x0001;
const _argsAreXyValues = 0x0002;
const _roundXyToGrid = 0x0004;
const _hasScale = 0x0008;
const _moreComponents = 0x0020;
const _hasXAndYScale = 0x0040;
const _hasTwoByTwo = 0x0080;
const _hasInstructions = 0x0100;
const _useMyMetrics = 0x0200;
const _scaledComponentOffset = 0x0800;
const _unscaledComponentOffset = 0x1000;

/// Decodes one TrueType glyph into closed cubic contours.
GlyphOutline readTrueTypeGlyph(
  OpenTypeFont font,
  int glyphId, {
  Map<String, double> variationCoordinates = const <String, double>{},
}) {
  try {
    final normalized = font.normalizedVariationCoordinates(
      variationCoordinates,
    );
    final decoded = _TrueTypeDecoder(font, normalized).read(glyphId);
    return GlyphOutline(
      contours: decoded.contours,
      advanceWidth:
          font.advanceWidth(decoded.metricsGlyphId ?? glyphId) +
          decoded.advanceDelta.round(),
      metrics: font.metrics,
    );
  } on FontDataException catch (error) {
    if (error.tableTag != null && error.glyphId != null) rethrow;
    throw FontDataException(
      error.message,
      tableTag: error.tableTag ?? 'glyf',
      glyphId: error.glyphId ?? glyphId,
      cause: error,
    );
  }
}

final class _TrueTypeDecoder {
  _TrueTypeDecoder(this.font, this.normalizedCoordinates)
    : glyf = font.requiredTable('glyf'),
      loca = font.requiredTable('loca') {
    final entrySize = font.indexToLocFormat == 0 ? 2 : 4;
    loca.require(0, entrySize * (font.numGlyphs + 1));
    var previous = 0;
    for (var index = 0; index <= font.numGlyphs; index++) {
      final offset = font.indexToLocFormat == 0
          ? 2 * loca.uint16(2 * index)
          : loca.uint32(4 * index);
      if (offset < previous || offset > glyf.length) {
        throw const FontDataException(
          'Invalid or decreasing glyph location',
          tableTag: 'loca',
        );
      }
      offsets.add(offset);
      previous = offset;
    }
  }

  final OpenTypeFont font;
  final List<double> normalizedCoordinates;
  final BinaryReader glyf;
  final BinaryReader loca;
  final List<int> offsets = <int>[];
  final _CompositeBudget budget = _CompositeBudget();

  _DecodedGlyph read(int glyphId) => _read(glyphId, <int>{}, 0);

  _DecodedGlyph _read(int glyphId, Set<int> activeGlyphs, int depth) {
    if (glyphId < 0 || glyphId >= font.numGlyphs) {
      throw FontDataException('Invalid glyph id: $glyphId', glyphId: glyphId);
    }
    if (!activeGlyphs.add(glyphId)) {
      throw FontDataException('Composite glyph cycle', glyphId: glyphId);
    }
    try {
      final start = offsets[glyphId];
      final end = offsets[glyphId + 1];
      if (start == end) return _DecodedGlyph.empty();
      final glyph = glyf.slice(start, end - start)..require(0, 10);
      final contourCount = glyph.int16(0);
      if (contourCount > maxGlyphContourCount) {
        throw FontDataException(
          'Glyph exceeds the contour limit',
          glyphId: glyphId,
        );
      }
      if (contourCount >= 0) {
        return _readSimple(glyph, contourCount, glyphId);
      }
      if (contourCount != -1) {
        throw FontDataException(
          'Invalid glyph contour count: $contourCount',
          glyphId: glyphId,
        );
      }
      if (depth >= maxCompositeDepth) {
        throw FontDataException(
          'Composite glyph exceeds the depth limit',
          glyphId: glyphId,
        );
      }
      return _readComposite(glyph, glyphId, activeGlyphs, depth);
    } on FontDataException catch (error) {
      if (error.glyphId != null) rethrow;
      throw FontDataException(
        error.message,
        tableTag: error.tableTag ?? 'glyf',
        glyphId: glyphId,
        cause: error,
      );
    } finally {
      activeGlyphs.remove(glyphId);
    }
  }

  _DecodedGlyph _readSimple(BinaryReader glyph, int contourCount, int glyphId) {
    var cursor = 10;
    if (contourCount == 0) {
      final instructionLength = glyph.uint16(cursor);
      cursor += 2;
      glyph.require(cursor, instructionLength);
      return _DecodedGlyph.empty();
    }
    glyph.require(cursor, 2 * contourCount);
    final endPoints = <int>[];
    var previousEnd = -1;
    for (var index = 0; index < contourCount; index++) {
      final end = glyph.uint16(cursor);
      cursor += 2;
      if (end <= previousEnd) {
        throw FontDataException(
          'Simple glyph contour endpoints are not increasing',
          glyphId: glyphId,
        );
      }
      endPoints.add(end);
      previousEnd = end;
    }
    final pointCount = endPoints.last + 1;
    if (pointCount > maxGlyphPointCount) {
      throw FontDataException(
        'Glyph exceeds the point limit',
        glyphId: glyphId,
      );
    }

    final instructionLength = glyph.uint16(cursor);
    cursor += 2;
    glyph.require(cursor, instructionLength);
    cursor += instructionLength;

    final flags = <int>[];
    while (flags.length < pointCount) {
      final flag = glyph.uint8(cursor++);
      if (flag & 0xc0 != 0) {
        throw FontDataException(
          'Simple glyph uses reserved point flags',
          glyphId: glyphId,
        );
      }
      flags.add(flag);
      if (flag & _repeat == 0) continue;
      final repetitions = glyph.uint8(cursor++);
      if (flags.length + repetitions > pointCount) {
        throw FontDataException(
          'Simple glyph flag repeat exceeds its point count',
          glyphId: glyphId,
        );
      }
      for (var index = 0; index < repetitions; index++) {
        flags.add(flag & ~_repeat);
      }
    }

    final xs = List<int>.filled(pointCount, 0, growable: false);
    var coordinate = 0;
    for (var index = 0; index < pointCount; index++) {
      final flag = flags[index];
      if (flag & _xShort != 0) {
        final delta = glyph.uint8(cursor++);
        coordinate += flag & _xSameOrPositive != 0 ? delta : -delta;
      } else if (flag & _xSameOrPositive == 0) {
        coordinate += glyph.int16(cursor);
        cursor += 2;
      }
      xs[index] = coordinate;
    }

    var points = <_Point>[];
    coordinate = 0;
    for (var index = 0; index < pointCount; index++) {
      final flag = flags[index];
      if (flag & _yShort != 0) {
        final delta = glyph.uint8(cursor++);
        coordinate += flag & _ySameOrPositive != 0 ? delta : -delta;
      } else if (flag & _ySameOrPositive == 0) {
        coordinate += glyph.int16(cursor);
        cursor += 2;
      }
      points.add(
        _Point(
          xs[index].toDouble(),
          coordinate.toDouble(),
          flag & _onCurve != 0,
        ),
      );
    }

    var advanceDelta = 0.0;
    if (normalizedCoordinates.any((value) => value != 0)) {
      final gvar = font.table('gvar');
      if (gvar == null) {
        throw const FontDataException(
          'Variable TrueType font has no gvar table',
          tableTag: 'gvar',
        );
      }
      final adjusted = applySimpleGlyphVariations(
        gvar: gvar,
        expectedAxisCount: font.variationAxes.length,
        expectedGlyphCount: font.numGlyphs,
        glyphId: glyphId,
        normalizedCoordinates: normalizedCoordinates,
        x: <double>[for (final point in points) point.x],
        y: <double>[for (final point in points) point.y],
        contourEnds: endPoints,
      );
      points = <_Point>[
        for (var index = 0; index < points.length; index++)
          _Point(adjusted.x[index], adjusted.y[index], points[index].onCurve),
      ];
      advanceDelta = adjusted.advanceDelta;
    }

    final contours = <CubicContour>[];
    var start = 0;
    for (final end in endPoints) {
      contours.add(_buildContour(points.sublist(start, end + 1)));
      start = end + 1;
    }
    return _DecodedGlyph(contours, points, advanceDelta: advanceDelta);
  }

  _DecodedGlyph _readComposite(
    BinaryReader glyph,
    int glyphId,
    Set<int> activeGlyphs,
    int depth,
  ) {
    final variation = _compositeVariation(glyph, glyphId);
    final contours = <CubicContour>[];
    final points = <_Point>[];
    int? metricsGlyphId;
    var cursor = 10;
    var instructionsFollow = false;
    var more = true;
    var componentIndex = 0;
    var advanceDelta = variation?.advanceDelta ?? 0.0;
    while (more) {
      budget.take(glyphId);
      glyph.require(cursor, 4);
      final flags = glyph.uint16(cursor);
      final componentGlyphId = glyph.uint16(cursor + 2);
      cursor += 4;
      if (flags & 0xe010 != 0) {
        throw FontDataException(
          'Composite glyph uses reserved flags',
          glyphId: glyphId,
        );
      }

      final words = flags & _argsAreWords != 0;
      final xyValues = flags & _argsAreXyValues != 0;
      late final int argument1;
      late final int argument2;
      if (words) {
        argument1 = xyValues ? glyph.int16(cursor) : glyph.uint16(cursor);
        argument2 = xyValues
            ? glyph.int16(cursor + 2)
            : glyph.uint16(cursor + 2);
        cursor += 4;
      } else {
        argument1 = xyValues ? glyph.int8(cursor) : glyph.uint8(cursor);
        argument2 = xyValues ? glyph.int8(cursor + 1) : glyph.uint8(cursor + 1);
        cursor += 2;
      }

      final transformKinds =
          (flags & _hasScale != 0 ? 1 : 0) +
          (flags & _hasXAndYScale != 0 ? 1 : 0) +
          (flags & _hasTwoByTwo != 0 ? 1 : 0);
      if (transformKinds > 1 ||
          flags & _scaledComponentOffset != 0 &&
              flags & _unscaledComponentOffset != 0) {
        throw FontDataException(
          'Composite glyph has conflicting transform flags',
          glyphId: glyphId,
        );
      }
      var transform = const _Affine.identity();
      if (flags & _hasScale != 0) {
        final scale = glyph.f2Dot14(cursor);
        cursor += 2;
        transform = _Affine(scale, 0, 0, scale);
      } else if (flags & _hasXAndYScale != 0) {
        transform = _Affine(
          glyph.f2Dot14(cursor),
          0,
          0,
          glyph.f2Dot14(cursor + 2),
        );
        cursor += 4;
      } else if (flags & _hasTwoByTwo != 0) {
        transform = _Affine(
          glyph.f2Dot14(cursor),
          glyph.f2Dot14(cursor + 2),
          glyph.f2Dot14(cursor + 4),
          glyph.f2Dot14(cursor + 6),
        );
        cursor += 8;
      }

      final child = _read(componentGlyphId, activeGlyphs, depth + 1);
      var offsetX = 0.0;
      var offsetY = 0.0;
      if (xyValues) {
        offsetX = variation?.x[componentIndex] ?? argument1.toDouble();
        offsetY = variation?.y[componentIndex] ?? argument2.toDouble();
        if (flags & _scaledComponentOffset != 0) {
          final scaled = transform.apply(offsetX, offsetY);
          offsetX = scaled.$1;
          offsetY = scaled.$2;
        }
        if (flags & _roundXyToGrid != 0) {
          offsetX = offsetX.roundToDouble();
          offsetY = offsetY.roundToDouble();
        }
      } else {
        if (argument1 >= points.length || argument2 >= child.points.length) {
          throw FontDataException(
            'Composite point attachment is out of range',
            glyphId: glyphId,
          );
        }
        final parentPoint = points[argument1];
        final componentPoint = transform.apply(
          child.points[argument2].x,
          child.points[argument2].y,
        );
        offsetX = parentPoint.x - componentPoint.$1;
        offsetY = parentPoint.y - componentPoint.$2;
      }

      final transformed = child.transformed(transform, offsetX, offsetY);
      if (contours.length + transformed.contours.length >
              maxGlyphContourCount ||
          points.length + transformed.points.length > maxGlyphPointCount) {
        throw FontDataException(
          'Expanded composite glyph exceeds geometry limits',
          glyphId: glyphId,
        );
      }
      contours.addAll(transformed.contours);
      points.addAll(transformed.points);
      if (flags & _useMyMetrics != 0) {
        metricsGlyphId = child.metricsGlyphId ?? componentGlyphId;
        advanceDelta = child.advanceDelta;
      }
      instructionsFollow = instructionsFollow || flags & _hasInstructions != 0;
      more = flags & _moreComponents != 0;
      componentIndex++;
    }

    if (instructionsFollow) {
      final instructionLength = glyph.uint16(cursor);
      cursor += 2;
      glyph.require(cursor, instructionLength);
    }
    return _DecodedGlyph(
      contours,
      points,
      metricsGlyphId: metricsGlyphId,
      advanceDelta: advanceDelta,
    );
  }

  GlyphVariationAdjustments? _compositeVariation(
    BinaryReader glyph,
    int glyphId,
  ) {
    if (!normalizedCoordinates.any((value) => value != 0)) return null;
    final gvar = font.table('gvar');
    if (gvar == null) {
      throw const FontDataException(
        'Variable TrueType font has no gvar table',
        tableTag: 'gvar',
      );
    }
    if (!glyphHasVariationData(
      gvar: gvar,
      glyphId: glyphId,
      expectedGlyphCount: font.numGlyphs,
    )) {
      return null;
    }

    final x = <double>[];
    final y = <double>[];
    var cursor = 10;
    var more = true;
    while (more) {
      glyph.require(cursor, 4);
      final flags = glyph.uint16(cursor);
      cursor += 4;
      final words = flags & _argsAreWords != 0;
      final xyValues = flags & _argsAreXyValues != 0;
      late final int argument1;
      late final int argument2;
      if (words) {
        argument1 = xyValues ? glyph.int16(cursor) : glyph.uint16(cursor);
        argument2 = xyValues
            ? glyph.int16(cursor + 2)
            : glyph.uint16(cursor + 2);
        cursor += 4;
      } else {
        argument1 = xyValues ? glyph.int8(cursor) : glyph.uint8(cursor);
        argument2 = xyValues ? glyph.int8(cursor + 1) : glyph.uint8(cursor + 1);
        cursor += 2;
      }
      x.add(xyValues ? argument1.toDouble() : 0);
      y.add(xyValues ? argument2.toDouble() : 0);
      cursor += flags & _hasTwoByTwo != 0
          ? 8
          : flags & _hasXAndYScale != 0
          ? 4
          : flags & _hasScale != 0
          ? 2
          : 0;
      glyph.require(cursor, 0);
      more = flags & _moreComponents != 0;
      if (x.length > maxCompositeComponentCount) {
        throw FontDataException(
          'Composite glyph exceeds the component limit',
          glyphId: glyphId,
        );
      }
    }
    return applySimpleGlyphVariations(
      gvar: gvar,
      expectedAxisCount: font.variationAxes.length,
      expectedGlyphCount: font.numGlyphs,
      glyphId: glyphId,
      normalizedCoordinates: normalizedCoordinates,
      x: x,
      y: y,
      contourEnds: const <int>[],
    );
  }
}

final class _CompositeBudget {
  var remaining = maxCompositeComponentCount;

  void take(int glyphId) {
    if (remaining-- <= 0) {
      throw FontDataException(
        'Composite glyph exceeds the component limit',
        glyphId: glyphId,
      );
    }
  }
}

final class _DecodedGlyph {
  const _DecodedGlyph(
    this.contours,
    this.points, {
    this.metricsGlyphId,
    this.advanceDelta = 0,
  });

  factory _DecodedGlyph.empty() =>
      const _DecodedGlyph(<CubicContour>[], <_Point>[]);

  final List<CubicContour> contours;
  final List<_Point> points;
  final int? metricsGlyphId;
  final double advanceDelta;

  _DecodedGlyph transformed(_Affine transform, double dx, double dy) {
    final transformedContours = <CubicContour>[];
    for (final contour in contours) {
      final source = contour.points;
      final target = Float64List(source.length);
      for (var index = 0; index < source.length; index += 2) {
        final point = transform.apply(source[index], source[index + 1]);
        target[index] = point.$1 + dx;
        target[index + 1] = point.$2 + dy;
      }
      transformedContours.add(CubicContour(target));
    }
    final transformedPoints = <_Point>[];
    for (final source in points) {
      final point = transform.apply(source.x, source.y);
      transformedPoints.add(
        _Point(point.$1 + dx, point.$2 + dy, source.onCurve),
      );
    }
    return _DecodedGlyph(
      transformedContours,
      transformedPoints,
      metricsGlyphId: metricsGlyphId,
      advanceDelta: advanceDelta,
    );
  }
}

final class _Point {
  const _Point(this.x, this.y, this.onCurve);

  final double x;
  final double y;
  final bool onCurve;
}

final class _Affine {
  const _Affine(this.m00, this.m01, this.m10, this.m11);
  const _Affine.identity() : this(1, 0, 0, 1);

  final double m00;
  final double m01;
  final double m10;
  final double m11;

  (double, double) apply(double x, double y) =>
      (m00 * x + m01 * y, m10 * x + m11 * y);
}

CubicContour _buildContour(List<_Point> points) {
  final first = points.first;
  final last = points.last;
  late final _Point start;
  late final List<_Point> sequence;
  if (first.onCurve) {
    start = first;
    sequence = <_Point>[...points.skip(1), first];
  } else if (last.onCurve) {
    start = last;
    sequence = <_Point>[...points.take(points.length - 1), last];
  } else {
    start = _midpoint(last, first);
    sequence = <_Point>[...points, start];
  }

  final builder = CubicContourBuilder()..moveTo(start.x, start.y);
  var index = 0;
  while (index < sequence.length) {
    final point = sequence[index];
    if (point.onCurve) {
      builder.lineTo(point.x, point.y);
      index++;
      continue;
    }
    final next = sequence[index + 1];
    if (next.onCurve) {
      builder.quadraticTo(point.x, point.y, next.x, next.y);
      index += 2;
    } else {
      final implied = _midpoint(point, next);
      builder.quadraticTo(point.x, point.y, implied.x, implied.y);
      index++;
    }
  }
  return builder.close();
}

_Point _midpoint(_Point a, _Point b) =>
    _Point((a.x + b.x) / 2, (a.y + b.y) / 2, true);
