import 'dart:math' as math;

import 'binary_reader.dart';

const _sharedPointNumbers = 0x8000;
const _embeddedPeakTuple = 0x8000;
const _intermediateRegion = 0x4000;
const _privatePointNumbers = 0x2000;
const _tupleCountMask = 0x0fff;
const _tupleIndexMask = 0x0fff;

final class GlyphVariationAdjustments {
  const GlyphVariationAdjustments(this.x, this.y, this.advanceDelta);

  final List<double> x;
  final List<double> y;
  final double advanceDelta;
}

bool glyphHasVariationData({
  required BinaryReader gvar,
  required int glyphId,
  required int expectedGlyphCount,
}) {
  gvar.require(0, 20);
  final glyphCount = gvar.uint16(12);
  final flags = gvar.uint16(14);
  if (gvar.uint16(0) != 1 ||
      glyphCount != expectedGlyphCount ||
      glyphId < 0 ||
      glyphId >= glyphCount ||
      flags & ~1 != 0) {
    throw const FontDataException('Invalid gvar glyph count', tableTag: 'gvar');
  }
  final longOffsets = flags & 1 != 0;
  gvar.require(20, (longOffsets ? 4 : 2) * (glyphCount + 1));
  int offset(int index) => longOffsets
      ? gvar.uint32(20 + 4 * index)
      : 2 * gvar.uint16(20 + 2 * index);
  return offset(glyphId) != offset(glyphId + 1);
}

/// Applies a TrueType `gvar` tuple store to one simple glyph.
GlyphVariationAdjustments applySimpleGlyphVariations({
  required BinaryReader gvar,
  required int expectedAxisCount,
  required int expectedGlyphCount,
  required int glyphId,
  required List<double> normalizedCoordinates,
  required List<double> x,
  required List<double> y,
  required List<int> contourEnds,
}) {
  gvar.require(0, 20);
  final axisCount = gvar.uint16(4);
  final sharedTupleCount = gvar.uint16(6);
  final sharedTuplesOffset = gvar.uint32(8);
  final glyphCount = gvar.uint16(12);
  final flags = gvar.uint16(14);
  final dataArrayOffset = gvar.uint32(16);
  if (gvar.uint16(0) != 1 ||
      axisCount != expectedAxisCount ||
      glyphCount != expectedGlyphCount ||
      normalizedCoordinates.length != axisCount ||
      flags & ~1 != 0) {
    throw const FontDataException('Invalid gvar header', tableTag: 'gvar');
  }

  final longOffsets = flags & 1 != 0;
  final offsetSize = longOffsets ? 4 : 2;
  gvar.require(20, offsetSize * (glyphCount + 1));
  int glyphOffset(int index) => longOffsets
      ? gvar.uint32(20 + 4 * index)
      : 2 * gvar.uint16(20 + 2 * index);
  final start = dataArrayOffset + glyphOffset(glyphId);
  final end = dataArrayOffset + glyphOffset(glyphId + 1);
  if (start == end) {
    return GlyphVariationAdjustments(List<double>.of(x), List<double>.of(y), 0);
  }
  if (end < start) {
    throw const FontDataException(
      'Invalid gvar glyph offsets',
      tableTag: 'gvar',
    );
  }

  gvar.require(sharedTuplesOffset, 2 * axisCount * sharedTupleCount);
  final sharedTuples = <List<double>>[];
  var sharedCursor = sharedTuplesOffset;
  for (var tuple = 0; tuple < sharedTupleCount; tuple++) {
    sharedTuples.add(<double>[
      for (var axis = 0; axis < axisCount; axis++)
        gvar.f2Dot14(sharedCursor + 2 * axis),
    ]);
    sharedCursor += 2 * axisCount;
  }

  final glyph = gvar.slice(start, end - start)..require(0, 4);
  final countAndFlags = glyph.uint16(0);
  final tupleCount = countAndFlags & _tupleCountMask;
  final dataOffset = glyph.uint16(2);
  var headerCursor = 4;
  final headers = <_TupleHeader>[];
  for (var tuple = 0; tuple < tupleCount; tuple++) {
    glyph.require(headerCursor, 4);
    final dataSize = glyph.uint16(headerCursor);
    final tupleIndex = glyph.uint16(headerCursor + 2);
    headerCursor += 4;
    late final List<double> peak;
    if (tupleIndex & _embeddedPeakTuple != 0) {
      glyph.require(headerCursor, 2 * axisCount);
      peak = <double>[
        for (var axis = 0; axis < axisCount; axis++)
          glyph.f2Dot14(headerCursor + 2 * axis),
      ];
      headerCursor += 2 * axisCount;
    } else {
      final sharedIndex = tupleIndex & _tupleIndexMask;
      if (sharedIndex >= sharedTuples.length) {
        throw const FontDataException(
          'Invalid shared gvar tuple index',
          tableTag: 'gvar',
        );
      }
      peak = sharedTuples[sharedIndex];
    }
    List<double>? regionStart;
    List<double>? regionEnd;
    if (tupleIndex & _intermediateRegion != 0) {
      glyph.require(headerCursor, 4 * axisCount);
      regionStart = <double>[
        for (var axis = 0; axis < axisCount; axis++)
          glyph.f2Dot14(headerCursor + 2 * axis),
      ];
      headerCursor += 2 * axisCount;
      regionEnd = <double>[
        for (var axis = 0; axis < axisCount; axis++)
          glyph.f2Dot14(headerCursor + 2 * axis),
      ];
      headerCursor += 2 * axisCount;
    }
    headers.add(
      _TupleHeader(
        dataSize: dataSize,
        privatePoints: tupleIndex & _privatePointNumbers != 0,
        scalar: _tupleScalar(
          normalizedCoordinates,
          peak,
          regionStart,
          regionEnd,
        ),
      ),
    );
  }
  if (headerCursor > dataOffset) {
    throw const FontDataException('Overlapping gvar data', tableTag: 'gvar');
  }

  final serialized = _Cursor(glyph, dataOffset, glyph.length);
  final pointTotal = x.length + 4;
  final sharedPoints = countAndFlags & _sharedPointNumbers != 0
      ? _readPackedPoints(serialized, pointTotal)
      : null;
  var tupleDataOffset = serialized.offset;
  final netX = List<double>.filled(pointTotal, 0);
  final netY = List<double>.filled(pointTotal, 0);
  for (final header in headers) {
    final tupleEnd = tupleDataOffset + header.dataSize;
    if (tupleEnd > glyph.length) {
      throw const FontDataException(
        'Truncated gvar tuple data',
        tableTag: 'gvar',
      );
    }
    final data = _Cursor(glyph, tupleDataOffset, tupleEnd);
    tupleDataOffset = tupleEnd;
    final points = header.privatePoints
        ? _readPackedPoints(data, pointTotal)
        : sharedPoints;
    final deltaCount = points?.length ?? pointTotal;
    final deltaX = _readPackedDeltas(data, deltaCount);
    final deltaY = _readPackedDeltas(data, deltaCount);
    if (header.scalar == 0) continue;

    final explicitX = List<double?>.filled(pointTotal, null);
    final explicitY = List<double?>.filled(pointTotal, null);
    for (var index = 0; index < deltaCount; index++) {
      final point = points?[index] ?? index;
      if (point >= pointTotal) {
        throw const FontDataException(
          'Invalid gvar point index',
          tableTag: 'gvar',
        );
      }
      explicitX[point] = (explicitX[point] ?? 0) + deltaX[index];
      explicitY[point] = (explicitY[point] ?? 0) + deltaY[index];
    }
    _inferUntouched(x, explicitX, contourEnds);
    _inferUntouched(y, explicitY, contourEnds);
    for (var point = 0; point < pointTotal; point++) {
      netX[point] += (explicitX[point] ?? 0) * header.scalar;
      netY[point] += (explicitY[point] ?? 0) * header.scalar;
    }
  }

  return GlyphVariationAdjustments(
    <double>[for (var i = 0; i < x.length; i++) x[i] + netX[i]],
    <double>[for (var i = 0; i < y.length; i++) y[i] + netY[i]],
    netX[x.length + 1] - netX[x.length],
  );
}

double _tupleScalar(
  List<double> coordinates,
  List<double> peak,
  List<double>? regionStart,
  List<double>? regionEnd,
) {
  var scalar = 1.0;
  for (var axis = 0; axis < coordinates.length; axis++) {
    final peakValue = peak[axis];
    if (peakValue == 0) continue;
    final coordinate = coordinates[axis];
    if (regionStart != null && regionEnd != null) {
      final start = regionStart[axis];
      final end = regionEnd[axis];
      if (start > peakValue ||
          peakValue > end ||
          coordinate < start ||
          coordinate > end) {
        return 0;
      }
      if (coordinate < peakValue) {
        if (peakValue != start) {
          scalar *= (coordinate - start) / (peakValue - start);
        }
      } else if (coordinate > peakValue) {
        if (end != peakValue) scalar *= (end - coordinate) / (end - peakValue);
      }
    } else {
      if (coordinate == 0 ||
          coordinate.sign != peakValue.sign ||
          coordinate.abs() > peakValue.abs()) {
        return 0;
      }
      scalar *= coordinate / peakValue;
    }
  }
  return scalar.clamp(0.0, 1.0);
}

List<int>? _readPackedPoints(_Cursor cursor, int maximum) {
  final first = cursor.uint8();
  if (first == 0) return null;
  final count = first & 0x80 == 0
      ? first
      : ((first & 0x7f) << 8) | cursor.uint8();
  if (count > maximum) {
    throw const FontDataException('Too many gvar points', tableTag: 'gvar');
  }
  final result = <int>[];
  var point = 0;
  while (result.length < count) {
    final control = cursor.uint8();
    final runCount = (control & 0x7f) + 1;
    if (result.length + runCount > count) {
      throw const FontDataException('Invalid gvar point run', tableTag: 'gvar');
    }
    for (var index = 0; index < runCount; index++) {
      point += control & 0x80 == 0 ? cursor.uint8() : cursor.uint16();
      result.add(point);
    }
  }
  return result;
}

List<double> _readPackedDeltas(_Cursor cursor, int count) {
  final result = <double>[];
  while (result.length < count) {
    final control = cursor.uint8();
    final runCount = (control & 0x3f) + 1;
    if (result.length + runCount > count) {
      throw const FontDataException('Invalid gvar delta run', tableTag: 'gvar');
    }
    if (control & 0x80 != 0) {
      result.addAll(List<double>.filled(runCount, 0));
    } else if (control & 0x40 != 0) {
      for (var index = 0; index < runCount; index++) {
        result.add(cursor.int16().toDouble());
      }
    } else {
      for (var index = 0; index < runCount; index++) {
        result.add(cursor.int8().toDouble());
      }
    }
  }
  return result;
}

void _inferUntouched(
  List<double> coordinates,
  List<double?> deltas,
  List<int> contourEnds,
) {
  var contourStart = 0;
  for (final contourEnd in contourEnds) {
    final touched = <int>[
      for (var point = contourStart; point <= contourEnd; point++)
        if (deltas[point] != null) point,
    ];
    if (touched.length == 1) {
      for (var point = contourStart; point <= contourEnd; point++) {
        deltas[point] ??= deltas[touched.single];
      }
    } else if (touched.length > 1) {
      for (var index = 0; index < touched.length; index++) {
        final before = touched[index];
        final after = touched[(index + 1) % touched.length];
        var point = before == contourEnd ? contourStart : before + 1;
        while (point != after) {
          deltas[point] = _interpolateDelta(
            coordinates[point],
            coordinates[before],
            deltas[before]!,
            coordinates[after],
            deltas[after]!,
          );
          point = point == contourEnd ? contourStart : point + 1;
        }
      }
    }
    contourStart = contourEnd + 1;
  }
}

double _interpolateDelta(
  double coordinate,
  double beforeCoordinate,
  double beforeDelta,
  double afterCoordinate,
  double afterDelta,
) {
  if (beforeCoordinate == afterCoordinate) {
    return beforeDelta == afterDelta ? beforeDelta : 0;
  }
  final minimum = math.min(beforeCoordinate, afterCoordinate);
  final maximum = math.max(beforeCoordinate, afterCoordinate);
  if (coordinate <= minimum) {
    return beforeCoordinate < afterCoordinate ? beforeDelta : afterDelta;
  }
  if (coordinate >= maximum) {
    return beforeCoordinate > afterCoordinate ? beforeDelta : afterDelta;
  }
  return beforeDelta +
      (coordinate - beforeCoordinate) *
          (afterDelta - beforeDelta) /
          (afterCoordinate - beforeCoordinate);
}

final class _TupleHeader {
  const _TupleHeader({
    required this.dataSize,
    required this.privatePoints,
    required this.scalar,
  });

  final int dataSize;
  final bool privatePoints;
  final double scalar;
}

final class _Cursor {
  _Cursor(this.reader, this.offset, this.limit);

  final BinaryReader reader;
  int offset;
  final int limit;

  int uint8() {
    _require(1);
    return reader.uint8(offset++);
  }

  int int8() {
    _require(1);
    return reader.int8(offset++);
  }

  int uint16() {
    _require(2);
    final value = reader.uint16(offset);
    offset += 2;
    return value;
  }

  int int16() {
    _require(2);
    final value = reader.int16(offset);
    offset += 2;
    return value;
  }

  void _require(int count) {
    if (offset < 0 || count < 0 || offset + count > limit) {
      throw const FontDataException('Truncated gvar data', tableTag: 'gvar');
    }
  }
}
