import 'dart:math' as math;
import 'dart:typed_data';

import 'shape.dart';

// Arc-length sampling is adapted from Morphicons' MIT-licensed resample.ts.
const _cornerThreshold = math.pi / 8;
const _lengthEpsilon = 1e-12;
const _gaussNodes = <double>[
  0.18343464249564978,
  0.525532409916329,
  0.7966664774136267,
  0.9602898564975363,
];
const _gaussWeights = <double>[
  0.362683783378362,
  0.31370664587788727,
  0.22238103445337448,
  0.10122853629037626,
];

/// Samples a closed cubic contour at fixed arc-length intervals.
Float64List resampleContour(CubicContour contour, {int pointCount = 64}) {
  if (pointCount < 2) {
    throw ArgumentError.value(pointCount, 'pointCount', 'Must be at least 2');
  }

  final points = contour.points;
  final segmentCount = contour.segmentCount;
  final output = Float64List(2 * pointCount);
  final lengths = List<double>.filled(segmentCount, 0);
  var totalLength = 0.0;
  for (var segment = 0; segment < segmentCount; segment++) {
    final length = _segmentLength(points, segment);
    lengths[segment] = length;
    totalLength += length;
  }
  if (totalLength < _lengthEpsilon) {
    for (var i = 0; i < pointCount; i++) {
      output[2 * i] = points[0];
      output[2 * i + 1] = points[1];
    }
    return output;
  }

  final corners = _detectCorners(
    points,
    lengths,
    segmentCount,
    _cornerThreshold,
  );
  final anchors = corners.isEmpty ? <int>[0] : corners;
  if (anchors.length > pointCount) {
    throw StateError(
      'pointCount=$pointCount cannot retain ${anchors.length} corners',
    );
  }

  final runs = <(int, int)>[
    for (var i = 0; i < anchors.length; i++)
      (
        anchors[i],
        i + 1 < anchors.length ? anchors[i + 1] : anchors.first + segmentCount,
      ),
  ];
  final runLengths = <double>[
    for (final (start, end) in runs)
      _sumWrapped(lengths, start, end, segmentCount),
  ];
  final counts = _apportionIntervals(runLengths, pointCount);

  var writeIndex = 0;
  for (var runIndex = 0; runIndex < runs.length; runIndex++) {
    final (start, end) = runs[runIndex];
    final intervalCount = counts[runIndex];
    final runLength = runLengths[runIndex];
    final pointOffset = 6 * (start % segmentCount);
    output[2 * writeIndex] = points[pointOffset];
    output[2 * writeIndex + 1] = points[pointOffset + 1];
    writeIndex++;

    var segment = start;
    var accumulated = 0.0;
    for (var interval = 1; interval < intervalCount; interval++) {
      final target = runLength * interval / intervalCount;
      while (segment < end - 1 &&
          accumulated + lengths[segment % segmentCount] < target) {
        accumulated += lengths[segment % segmentCount];
        segment++;
      }
      final wrappedSegment = segment % segmentCount;
      final segmentLength = lengths[wrappedSegment];
      final t = segmentLength > _lengthEpsilon
          ? _invertArcLength(
              points,
              wrappedSegment,
              target - accumulated,
              segmentLength,
            )
          : 0.0;
      _writePoint(points, wrappedSegment, t, output, 2 * writeIndex);
      writeIndex++;
    }
  }
  if (writeIndex != pointCount) {
    throw StateError('Sampler wrote $writeIndex of $pointCount points');
  }
  return output;
}

/// Samples cubic contours and derives their filled topology.
MorphShape sampleContours(
  List<CubicContour> contours, {
  int pointCount = 64,
  MorphFillRule fillRule = MorphFillRule.evenOdd,
}) => sampleContoursWithPointCounts(
  contours,
  pointCounts: List<int>.filled(contours.length, pointCount),
  fillRule: fillRule,
);

/// Samples each cubic contour with its own fixed point cardinality.
MorphShape sampleContoursWithPointCounts(
  List<CubicContour> contours, {
  required List<int> pointCounts,
  MorphFillRule fillRule = MorphFillRule.evenOdd,
}) {
  if (pointCounts.length != contours.length) {
    throw ArgumentError.value(
      pointCounts.length,
      'pointCounts.length',
      'Must match contours.length',
    );
  }
  return _sampledShapeFromPointBuffers(
    <Float64List>[
      for (var index = 0; index < contours.length; index++)
        resampleContour(contours[index], pointCount: pointCounts[index]),
    ],
    fillRule: fillRule,
    exactContours: contours,
  );
}

/// Recomputes topology for already sampled point buffers.
MorphShape sampledShapeFromPointBuffers(
  List<Float64List> pointBuffers, {
  MorphFillRule fillRule = MorphFillRule.evenOdd,
}) => _sampledShapeFromPointBuffers(pointBuffers, fillRule: fillRule);

MorphShape _sampledShapeFromPointBuffers(
  List<Float64List> pointBuffers, {
  required MorphFillRule fillRule,
  List<CubicContour>? exactContours,
}) {
  if (pointBuffers.isEmpty) {
    return MorphShape(const <SampledContour>[], fillRule: fillRule);
  }
  final sampled = <Float64List>[];
  for (final points in pointBuffers) {
    if (points.length < 4 ||
        points.length.isOdd ||
        !points.every((value) => value.isFinite)) {
      throw const FormatException('Invalid sampled point buffer');
    }
    sampled.add(Float64List.fromList(points));
  }

  final areas = sampled.map(_signedPolygonArea).toList(growable: false);
  final parents = List<int?>.filled(sampled.length, null);
  for (var child = 0; child < sampled.length; child++) {
    int? parent;
    for (var candidate = 0; candidate < sampled.length; candidate++) {
      if (candidate == child || areas[candidate].abs() <= areas[child].abs()) {
        continue;
      }
      if (!_polygonContains(
        sampled[candidate],
        sampled[child][0],
        sampled[child][1],
      )) {
        continue;
      }
      if (parent == null || areas[candidate].abs() < areas[parent].abs()) {
        parent = candidate;
      }
    }
    parents[child] = parent;
  }

  final depths = List<int>.filled(sampled.length, -1);
  int depthOf(int index, Set<int> active) {
    final known = depths[index];
    if (known >= 0) {
      return known;
    }
    if (!active.add(index)) {
      throw const FormatException('Cyclic contour topology');
    }
    final parent = parents[index];
    final depth = parent == null ? 0 : depthOf(parent, active) + 1;
    active.remove(index);
    return depths[index] = depth;
  }

  for (var i = 0; i < sampled.length; i++) {
    depthOf(i, <int>{});
  }

  final holes = List<bool>.filled(sampled.length, false);
  if (fillRule == MorphFillRule.evenOdd) {
    for (var i = 0; i < holes.length; i++) {
      holes[i] = depths[i].isOdd;
    }
  } else {
    final insideWindings = List<int?>.filled(sampled.length, null);
    int insideWinding(int index) {
      final known = insideWindings[index];
      if (known != null) return known;
      final parent = parents[index];
      final outside = parent == null ? 0 : insideWinding(parent);
      final sign = areas[index] > _lengthEpsilon
          ? 1
          : areas[index] < -_lengthEpsilon
          ? -1
          : 0;
      final inside = outside + sign;
      holes[index] = outside != 0 && inside == 0;
      insideWindings[index] = inside;
      return inside;
    }

    for (var i = 0; i < sampled.length; i++) {
      insideWinding(i);
    }
  }

  late final List<bool> reversed;
  if (fillRule == MorphFillRule.nonZero) {
    var reference = 0;
    for (var i = 1; i < areas.length; i++) {
      if (parents[i] == null && areas[i].abs() > areas[reference].abs()) {
        reference = i;
      }
    }
    reversed = List<bool>.filled(sampled.length, areas[reference] < 0);
  } else {
    reversed = List<bool>.generate(sampled.length, (index) {
      final area = areas[index];
      return holes[index] ? area > 0 : area < 0;
    });
  }
  final canonicalSampled = <Float64List>[
    for (var i = 0; i < sampled.length; i++)
      reversed[i] ? _reversedPointBuffer(sampled[i]) : sampled[i],
  ];
  final canonicalAreas = <double>[
    for (var i = 0; i < areas.length; i++) reversed[i] ? -areas[i] : areas[i],
  ];
  if (exactContours != null && exactContours.length != sampled.length) {
    throw const FormatException('Exact and sampled contour counts differ');
  }
  final canonicalExact = exactContours == null
      ? null
      : <CubicContour>[
          for (var i = 0; i < exactContours.length; i++)
            reversed[i]
                ? _reversedCubicContour(exactContours[i])
                : exactContours[i],
        ];

  final order = List<int>.generate(sampled.length, (index) => index)
    ..sort((a, b) {
      var comparison = depths[a].compareTo(depths[b]);
      if (comparison != 0) return comparison;
      comparison = canonicalAreas[b].abs().compareTo(canonicalAreas[a].abs());
      if (comparison != 0) return comparison;
      return _comparePointBuffers(canonicalSampled[a], canonicalSampled[b]);
    });
  final remapped = List<int>.filled(order.length, 0);
  for (var newIndex = 0; newIndex < order.length; newIndex++) {
    remapped[order[newIndex]] = newIndex;
  }

  return MorphShape(
    <SampledContour>[
      for (final oldIndex in order)
        SampledContour(
          canonicalSampled[oldIndex],
          signedArea: canonicalAreas[oldIndex],
          depth: depths[oldIndex],
          parent: parents[oldIndex] == null
              ? null
              : remapped[parents[oldIndex]!],
          isHole: holes[oldIndex],
        ),
    ],
    exactContours: canonicalExact == null
        ? null
        : <CubicContour>[
            for (final oldIndex in order) canonicalExact[oldIndex],
          ],
    fillRule: fillRule,
  );
}

Float64List _reversedPointBuffer(Float64List points) {
  final pointCount = points.length ~/ 2;
  final reversed = Float64List(points.length)
    ..[0] = points[0]
    ..[1] = points[1];
  for (var point = 1; point < pointCount; point++) {
    final source = pointCount - point;
    reversed[2 * point] = points[2 * source];
    reversed[2 * point + 1] = points[2 * source + 1];
  }
  return reversed;
}

CubicContour _reversedCubicContour(CubicContour contour) {
  final source = contour.points;
  final reversed = Float64List(source.length)
    ..[0] = source[0]
    ..[1] = source[1];
  var target = 2;
  for (var segment = contour.segmentCount - 1; segment >= 0; segment--) {
    final offset = 6 * segment;
    reversed[target++] = source[offset + 4];
    reversed[target++] = source[offset + 5];
    reversed[target++] = source[offset + 2];
    reversed[target++] = source[offset + 3];
    reversed[target++] = source[offset];
    reversed[target++] = source[offset + 1];
  }
  return CubicContour(reversed);
}

double _speed(Float64List points, int segment, double t) {
  final offset = 6 * segment;
  final u = 1 - t;
  final coefficient0 = 3 * u * u;
  final coefficient1 = 6 * u * t;
  final coefficient2 = 3 * t * t;
  final dx =
      coefficient0 * (points[offset + 2] - points[offset]) +
      coefficient1 * (points[offset + 4] - points[offset + 2]) +
      coefficient2 * (points[offset + 6] - points[offset + 4]);
  final dy =
      coefficient0 * (points[offset + 3] - points[offset + 1]) +
      coefficient1 * (points[offset + 5] - points[offset + 3]) +
      coefficient2 * (points[offset + 7] - points[offset + 5]);
  return math.sqrt(dx * dx + dy * dy);
}

double _segmentLength(Float64List points, int segment, [double end = 1]) {
  final half = end / 2;
  var sum = 0.0;
  for (var i = 0; i < _gaussNodes.length; i++) {
    sum +=
        _gaussWeights[i] *
        (_speed(points, segment, half + half * _gaussNodes[i]) +
            _speed(points, segment, half - half * _gaussNodes[i]));
  }
  return sum * half;
}

void _writePoint(
  Float64List points,
  int segment,
  double t,
  Float64List output,
  int outputOffset,
) {
  final offset = 6 * segment;
  final u = 1 - t;
  final b0 = u * u * u;
  final b1 = 3 * u * u * t;
  final b2 = 3 * u * t * t;
  final b3 = t * t * t;
  output[outputOffset] =
      b0 * points[offset] +
      b1 * points[offset + 2] +
      b2 * points[offset + 4] +
      b3 * points[offset + 6];
  output[outputOffset + 1] =
      b0 * points[offset + 1] +
      b1 * points[offset + 3] +
      b2 * points[offset + 5] +
      b3 * points[offset + 7];
}

(double, double)? _tangent(
  Float64List points,
  int segment, {
  required bool atEnd,
}) {
  final offset = 6 * segment;
  final base = atEnd ? offset + 6 : offset;
  final candidates = atEnd ? const <int>[4, 2, 0] : const <int>[2, 4, 6];
  for (final candidate in candidates) {
    final dx = atEnd
        ? points[base] - points[offset + candidate]
        : points[offset + candidate] - points[base];
    final dy = atEnd
        ? points[base + 1] - points[offset + candidate + 1]
        : points[offset + candidate + 1] - points[base + 1];
    if (dx * dx + dy * dy > 1e-18) {
      return (dx, dy);
    }
  }
  return null;
}

List<int> _detectCorners(
  Float64List points,
  List<double> lengths,
  int segmentCount,
  double threshold,
) {
  final active = <int>[
    for (var segment = 0; segment < segmentCount; segment++)
      if (lengths[segment] > 1e-9) segment,
  ];
  if (active.length < 2) {
    return const <int>[];
  }
  final corners = <int>{};
  void testJoint(int previous, int next) {
    final incoming = _tangent(points, previous, atEnd: true);
    final outgoing = _tangent(points, next, atEnd: false);
    if (incoming == null || outgoing == null) return;
    final angle = math
        .atan2(
          incoming.$1 * outgoing.$2 - incoming.$2 * outgoing.$1,
          incoming.$1 * outgoing.$1 + incoming.$2 * outgoing.$2,
        )
        .abs();
    if (angle > threshold) corners.add(next);
  }

  for (var i = 0; i + 1 < active.length; i++) {
    testJoint(active[i], active[i + 1]);
  }
  testJoint(active.last, active.first);
  return corners.toList()..sort();
}

double _sumWrapped(List<double> values, int start, int end, int modulus) {
  var sum = 0.0;
  for (var i = start; i < end; i++) {
    sum += values[i % modulus];
  }
  return sum;
}

List<int> _apportionIntervals(List<double> lengths, int intervalCount) {
  if (lengths.length > intervalCount) {
    throw StateError(
      '$intervalCount intervals cannot retain ${lengths.length} runs',
    );
  }
  final total = lengths.fold<double>(0, (sum, length) => sum + length);
  final ideals = <double>[
    for (final length in lengths) intervalCount * length / total,
  ];
  final counts = <int>[for (final ideal in ideals) math.max(1, ideal.floor())];
  var remaining =
      intervalCount - counts.fold<int>(0, (sum, count) => sum + count);
  if (remaining > 0) {
    final order = List<int>.generate(lengths.length, (index) => index)
      ..sort((a, b) {
        final fractionA = ((ideals[a] - ideals[a].floor()) * 1e9).round();
        final fractionB = ((ideals[b] - ideals[b].floor()) * 1e9).round();
        final comparison = fractionB.compareTo(fractionA);
        return comparison == 0 ? a.compareTo(b) : comparison;
      });
    for (var i = 0; i < remaining; i++) {
      counts[order[i % order.length]]++;
    }
  }
  while (remaining < 0) {
    var largest = 0;
    for (var i = 1; i < counts.length; i++) {
      if (counts[i] > counts[largest]) largest = i;
    }
    if (counts[largest] <= 1) {
      throw StateError('Unable to apportion $intervalCount intervals');
    }
    counts[largest]--;
    remaining++;
  }
  return counts;
}

double _invertArcLength(
  Float64List points,
  int segment,
  double target,
  double segmentLength,
) {
  if (target <= 0) return 0;
  if (target >= segmentLength) return 1;
  var lower = 0.0;
  var upper = 1.0;
  var t = target / segmentLength;
  for (var iteration = 0; iteration < 12; iteration++) {
    final difference = _segmentLength(points, segment, t) - target;
    if (difference.abs() < 1e-10 * segmentLength + 1e-14) break;
    if (difference > 0) {
      upper = t;
    } else {
      lower = t;
    }
    final speed = _speed(points, segment, t);
    var next = speed > 1e-12 ? t - difference / speed : (lower + upper) / 2;
    if (!(next > lower && next < upper)) {
      next = (lower + upper) / 2;
    }
    t = next;
  }
  return t;
}

double _signedPolygonArea(Float64List points) {
  var twiceArea = 0.0;
  final pointCount = points.length ~/ 2;
  for (var i = 0; i < pointCount; i++) {
    final next = (i + 1) % pointCount;
    twiceArea +=
        points[2 * i] * points[2 * next + 1] -
        points[2 * next] * points[2 * i + 1];
  }
  return twiceArea / 2;
}

bool _polygonContains(Float64List polygon, double x, double y) {
  var inside = false;
  final pointCount = polygon.length ~/ 2;
  for (var i = 0, previous = pointCount - 1; i < pointCount; previous = i++) {
    final x0 = polygon[2 * previous];
    final y0 = polygon[2 * previous + 1];
    final x1 = polygon[2 * i];
    final y1 = polygon[2 * i + 1];
    if (_pointOnSegment(x, y, x0, y0, x1, y1)) return true;
    if ((y1 > y) != (y0 > y) && x < (x0 - x1) * (y - y1) / (y0 - y1) + x1) {
      inside = !inside;
    }
  }
  return inside;
}

bool _pointOnSegment(
  double x,
  double y,
  double x0,
  double y0,
  double x1,
  double y1,
) {
  final cross = (x - x0) * (y1 - y0) - (y - y0) * (x1 - x0);
  if (cross.abs() > 1e-12) return false;
  final dot = (x - x0) * (x - x1) + (y - y0) * (y - y1);
  return dot <= 1e-12;
}

int _comparePointBuffers(Float64List a, Float64List b) {
  final commonLength = math.min(a.length, b.length);
  for (var i = 0; i < commonLength; i++) {
    final comparison = a[i].compareTo(b[i]);
    if (comparison != 0) return comparison;
  }
  return a.length.compareTo(b.length);
}
