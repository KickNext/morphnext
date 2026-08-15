import 'dart:math' as math;
import 'dart:typed_data';

import 'resample.dart';
import 'shape.dart';

// Correspondence and polar interpolation are adapted from Morphicons' MIT-
// licensed plan.ts and interpolate.ts. Filled-topology matching is local.
const _rotationTieBreak = 0.05;
const _globalResidualThreshold = 5e-3;
const _exactAssignmentLimit = 100000;
const _energyEpsilon = 1e-12;
const _minimumScale = 1e-6;
const _minimumFftAlignmentPointCount = 32;
const _alignmentScoreTolerance = 1e-7;
const _minimumStableSimilarityScale = 0.05;
const _maximumDegenerateSimilarityResidual = 0.95;

// Shape buffers are immutable in normal use. The coordinate copy also makes
// this weak cache safe when callers mutate a buffer between plan builds.
final Expando<_CachedAlignmentSpectrum> _alignmentSpectrumCache =
    Expando<_CachedAlignmentSpectrum>('morphnext alignment spectrum');

/// One aligned contour pair within a [MorphPlan].
final class MorphPlanItem {
  MorphPlanItem({
    required this.source,
    required this.sourceCentered,
    required this.targetInSourceFrame,
    required this.orientedTarget,
    required this.sourceCentroid,
    required this.targetCentroid,
    required this.theta,
    required this.logScale,
    required this.residual,
    required this.sourceCollapsed,
    required this.targetCollapsed,
  });

  /// Source points after correspondence selection.
  final Float64List source;

  /// Source points centered on [sourceCentroid].
  final Float64List sourceCentered;

  /// Target points transformed back into the source frame.
  final Float64List targetInSourceFrame;

  /// Target points after orientation and circular-offset selection.
  final Float64List orientedTarget;

  /// Source point-cloud centroid.
  final (double, double) sourceCentroid;

  /// Target point-cloud centroid.
  final (double, double) targetCentroid;

  /// Optimal source-to-target rotation in radians.
  double theta;

  /// Natural logarithm of the optimal positive scale.
  double logScale;

  /// Normalized Procrustes residual.
  double residual;

  /// Whether the source is a synthetic point contour.
  final bool sourceCollapsed;

  /// Whether the target is a synthetic point contour.
  final bool targetCollapsed;

  /// Offset from the global source centroid for rigid block transport.
  (double, double)? blockOffset;

  /// Linear correction that makes block transport exact at t=1.
  (double, double)? blockDrift;
}

/// A reusable, allocation-free interpolation plan between two filled shapes.
final class MorphPlan {
  MorphPlan(List<MorphPlanItem> items)
    : items = List<MorphPlanItem>.unmodifiable(items) {
    if (items.isEmpty) {
      throw const FormatException('A morph plan needs at least one contour');
    }
  }

  /// Aligned contour pairs.
  final List<MorphPlanItem> items;

  /// Allocates one correctly sized output buffer per contour pair.
  List<Float64List> allocateOutput() => <Float64List>[
    for (final item in items) Float64List(item.source.length),
  ];

  /// Interpolates [t] into caller-owned [output] buffers.
  void interpolate(double t, List<Float64List> output) {
    if (!t.isFinite) {
      throw ArgumentError.value(t, 't', 'Must be finite');
    }
    if (output.length != items.length) {
      throw ArgumentError.value(output.length, 'output.length');
    }
    final boundedT = t.clamp(-0.25, 1.25).toDouble();
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final points = output[index];
      if (points.length != item.source.length) {
        throw ArgumentError.value(points.length, 'output[$index].length');
      }
      _interpolateItem(item, boundedT, points);
    }
  }

  /// Returns newly allocated interpolated point buffers.
  List<Float64List> interpolatedCopy(double t) {
    final output = allocateOutput();
    interpolate(t, output);
    return output;
  }

  /// Freezes an intermediate frame as a new topology-aware source shape.
  MorphShape snapshot(double t) => sampledShapeFromPointBuffers(
    interpolatedCopy(t),
    fillRule: MorphFillRule.nonZero,
  );
}

/// Builds a topology-aware morph plan between [source] and [target].
MorphPlan buildMorphPlan(MorphShape source, MorphShape target) {
  _validateShapes(source, target);
  final pairs = _matchContours(source, target);
  final items = <MorphPlanItem>[];
  for (final (sourceIndex, targetIndex) in pairs) {
    final sourceCollapsed = sourceIndex == null;
    final targetCollapsed = targetIndex == null;
    final pointCount = _pairPointCount(
      source,
      target,
      sourceIndex,
      targetIndex,
    );
    final pointLength = 2 * pointCount;
    final sourcePoints = sourceCollapsed
        ? _collapsedPoints(
            pointLength,
            _collapsePoint(target.contours[targetIndex!], target, source),
          )
        : _pointsAtCardinality(source, sourceIndex, pointCount);
    final targetPoints = targetCollapsed
        ? _collapsedPoints(
            pointLength,
            _collapsePoint(source.contours[sourceIndex!], source, target),
          )
        : _pointsAtCardinality(target, targetIndex, pointCount);
    final alignment = _alignPair(
      sourcePoints,
      targetPoints,
      allowTargetReversal: target.fillRule == MorphFillRule.evenOdd,
    );
    items.add(
      _createItem(
        alignment,
        sourceCollapsed: sourceCollapsed,
        targetCollapsed: targetCollapsed,
      ),
    );
  }
  if (items.length > 1 &&
      items.every((item) => !item.sourceCollapsed && !item.targetCollapsed)) {
    _applyGlobalAlignment(items);
  }
  return MorphPlan(items);
}

void _validateShapes(MorphShape source, MorphShape target) {
  if (source.contours.isEmpty || target.contours.isEmpty) {
    throw const FormatException('Cannot morph an empty shape');
  }
  for (final shape in <MorphShape>[source, target]) {
    if (shape.exactContours case final exact?
        when exact.length != shape.contours.length) {
      throw const FormatException('Exact and sampled contour counts differ');
    }
    for (final contour in shape.contours) {
      if (contour.points.length < 4 ||
          contour.points.length.isOdd ||
          !contour.points.every((value) => value.isFinite)) {
        throw const FormatException('Invalid morph point cardinality');
      }
    }
  }
}

int _pairPointCount(
  MorphShape source,
  MorphShape target,
  int? sourceIndex,
  int? targetIndex,
) {
  final sourceCount = sourceIndex == null
      ? 0
      : source.contours[sourceIndex].points.length ~/ 2;
  final targetCount = targetIndex == null
      ? 0
      : target.contours[targetIndex].points.length ~/ 2;
  return math.max(sourceCount, targetCount);
}

Float64List _pointsAtCardinality(
  MorphShape shape,
  int contourIndex,
  int pointCount,
) {
  final points = shape.contours[contourIndex].points;
  final currentCount = points.length ~/ 2;
  if (currentCount == pointCount) return points;
  if (shape.exactContours case final exact?) {
    return resampleContour(exact[contourIndex], pointCount: pointCount);
  }
  if (pointCount % currentCount != 0) {
    throw const FormatException('Incompatible morph point cardinality');
  }
  return _subdividePolygon(points, pointCount ~/ currentCount);
}

Float64List _subdividePolygon(Float64List source, int factor) {
  final sourceCount = source.length ~/ 2;
  final output = Float64List(source.length * factor);
  var outputPoint = 0;
  for (var point = 0; point < sourceCount; point++) {
    final next = point + 1 == sourceCount ? 0 : point + 1;
    final x = source[2 * point];
    final y = source[2 * point + 1];
    final dx = source[2 * next] - x;
    final dy = source[2 * next + 1] - y;
    for (var step = 0; step < factor; step++) {
      final t = step / factor;
      output[2 * outputPoint] = x + dx * t;
      output[2 * outputPoint + 1] = y + dy * t;
      outputPoint++;
    }
  }
  return output;
}

List<(int?, int?)> _matchContours(MorphShape source, MorphShape target) {
  final pairs = <(int?, int?)>[];
  for (final isHole in const <bool>[false, true]) {
    final sourceIndices = <int>[
      for (var i = 0; i < source.contours.length; i++)
        if (source.contours[i].isHole == isHole) i,
    ];
    final targetIndices = <int>[
      for (var i = 0; i < target.contours.length; i++)
        if (target.contours[i].isHole == isHole) i,
    ];
    pairs.addAll(_matchRole(source, target, sourceIndices, targetIndices));
  }
  return pairs;
}

List<(int?, int?)> _matchRole(
  MorphShape source,
  MorphShape target,
  List<int> sourceIndices,
  List<int> targetIndices,
) {
  if (sourceIndices.isEmpty) {
    return <(int?, int?)>[
      for (final targetIndex in targetIndices) (null, targetIndex),
    ];
  }
  if (targetIndices.isEmpty) {
    return <(int?, int?)>[
      for (final sourceIndex in sourceIndices) (sourceIndex, null),
    ];
  }

  final sourceAreaScale = _maximumArea(source, sourceIndices);
  final targetAreaScale = _maximumArea(target, targetIndices);
  double cost(int sourcePosition, int targetPosition) => _contourCost(
    source,
    sourceIndices[sourcePosition],
    sourceAreaScale,
    target,
    targetIndices[targetPosition],
    targetAreaScale,
  );

  if (sourceIndices.length <= targetIndices.length) {
    final assignment = _minimumInjection(
      sourceIndices.length,
      targetIndices.length,
      cost,
    );
    final usedTargets = assignment.toSet();
    return <(int?, int?)>[
      for (
        var sourcePosition = 0;
        sourcePosition < sourceIndices.length;
        sourcePosition++
      )
        (
          sourceIndices[sourcePosition],
          targetIndices[assignment[sourcePosition]],
        ),
      for (
        var targetPosition = 0;
        targetPosition < targetIndices.length;
        targetPosition++
      )
        if (!usedTargets.contains(targetPosition))
          (null, targetIndices[targetPosition]),
    ];
  }

  final assignment = _minimumInjection(
    targetIndices.length,
    sourceIndices.length,
    (targetPosition, sourcePosition) => cost(sourcePosition, targetPosition),
  );
  final targetBySource = <int, int>{
    for (
      var targetPosition = 0;
      targetPosition < targetIndices.length;
      targetPosition++
    )
      assignment[targetPosition]: targetPosition,
  };
  return <(int?, int?)>[
    for (
      var sourcePosition = 0;
      sourcePosition < sourceIndices.length;
      sourcePosition++
    )
      targetBySource.containsKey(sourcePosition)
          ? (
              sourceIndices[sourcePosition],
              targetIndices[targetBySource[sourcePosition]!],
            )
          : (sourceIndices[sourcePosition], null),
  ];
}

double _maximumArea(MorphShape shape, List<int> indices) => indices
    .map((index) => shape.contours[index].signedArea.abs())
    .fold<double>(_energyEpsilon, math.max);

double _contourCost(
  MorphShape source,
  int sourceIndex,
  double sourceAreaScale,
  MorphShape target,
  int targetIndex,
  double targetAreaScale,
) {
  final sourceContour = source.contours[sourceIndex];
  final targetContour = target.contours[targetIndex];
  final sourceCentroid = _centroid(sourceContour.points);
  final targetCentroid = _centroid(targetContour.points);
  final centroidCost = _distance(sourceCentroid, targetCentroid);
  final sourceLength =
      _polygonLength(sourceContour.points) / math.sqrt(sourceAreaScale);
  final targetLength =
      _polygonLength(targetContour.points) / math.sqrt(targetAreaScale);
  final lengthCost = (sourceLength - targetLength).abs();
  final areaCost =
      (sourceContour.signedArea.abs() / sourceAreaScale -
              targetContour.signedArea.abs() / targetAreaScale)
          .abs();
  final depthCost = (sourceContour.depth - targetContour.depth).abs();
  var parentCost = 0.0;
  if ((sourceContour.parent == null) != (targetContour.parent == null)) {
    parentCost = 2;
  } else if (sourceContour.parent != null) {
    parentCost = _distance(
      _centroid(source.contours[sourceContour.parent!].points),
      _centroid(target.contours[targetContour.parent!].points),
    );
  }
  return centroidCost +
      0.35 * lengthCost +
      0.5 * areaCost +
      0.75 * depthCost +
      0.25 * parentCost;
}

List<int> _minimumInjection(
  int smallCount,
  int largeCount,
  double Function(int small, int large) cost,
) {
  var possibilities = 1;
  for (var i = 0; i < smallCount; i++) {
    possibilities *= largeCount - i;
    if (possibilities > _exactAssignmentLimit) break;
  }
  if (possibilities > _exactAssignmentLimit) {
    return _greedyInjection(smallCount, largeCount, cost);
  }

  final current = List<int>.filled(smallCount, -1);
  final used = List<bool>.filled(largeCount, false);
  var best = List<int>.filled(smallCount, -1);
  var bestCost = double.infinity;
  void search(int small, double accumulated) {
    if (accumulated >= bestCost) return;
    if (small == smallCount) {
      bestCost = accumulated;
      best = List<int>.from(current);
      return;
    }
    for (var large = 0; large < largeCount; large++) {
      if (used[large]) continue;
      used[large] = true;
      current[small] = large;
      search(small + 1, accumulated + cost(small, large));
      used[large] = false;
    }
  }

  search(0, 0);
  return best;
}

List<int> _greedyInjection(
  int smallCount,
  int largeCount,
  double Function(int small, int large) cost,
) {
  final candidates =
      <(double, int, int)>[
        for (var small = 0; small < smallCount; small++)
          for (var large = 0; large < largeCount; large++)
            (cost(small, large), small, large),
      ]..sort((a, b) {
        var comparison = a.$1.compareTo(b.$1);
        if (comparison != 0) return comparison;
        comparison = a.$2.compareTo(b.$2);
        return comparison != 0 ? comparison : a.$3.compareTo(b.$3);
      });
  final assignment = List<int>.filled(smallCount, -1);
  final usedLarge = List<bool>.filled(largeCount, false);
  for (final (_, small, large) in candidates) {
    if (assignment[small] < 0 && !usedLarge[large]) {
      assignment[small] = large;
      usedLarge[large] = true;
    }
  }
  for (var small = 0; small < smallCount; small++) {
    if (assignment[small] >= 0) continue;
    var bestLarge = -1;
    var bestCost = double.infinity;
    for (var large = 0; large < largeCount; large++) {
      final candidateCost = cost(small, large);
      if (!usedLarge[large] && candidateCost < bestCost) {
        bestCost = candidateCost;
        bestLarge = large;
      }
    }
    assignment[small] = bestLarge;
    usedLarge[bestLarge] = true;
  }
  return assignment;
}

(double, double) _collapsePoint(
  SampledContour actual,
  MorphShape actualShape,
  MorphShape otherShape,
) {
  final actualReference = actual.parent == null
      ? actual
      : actualShape.contours[actual.parent!];
  final candidates = <SampledContour>[
    for (final contour in otherShape.contours)
      if (contour.isHole == actualReference.isHole) contour,
  ];
  if (candidates.isEmpty) {
    return _shapeCentroid(otherShape);
  }
  final referenceCentroid = _centroid(actualReference.points);
  candidates.sort(
    (a, b) => _distance(
      _centroid(a.points),
      referenceCentroid,
    ).compareTo(_distance(_centroid(b.points), referenceCentroid)),
  );
  return _centroid(candidates.first.points);
}

(double, double) _shapeCentroid(MorphShape shape) {
  var x = 0.0;
  var y = 0.0;
  for (final contour in shape.contours) {
    final center = _centroid(contour.points);
    x += center.$1;
    y += center.$2;
  }
  return (x / shape.contours.length, y / shape.contours.length);
}

Float64List _collapsedPoints(int length, (double, double) point) {
  final output = Float64List(length);
  for (var i = 0; i < length; i += 2) {
    output[i] = point.$1;
    output[i + 1] = point.$2;
  }
  return output;
}

_Alignment _alignPair(
  Float64List source,
  Float64List target, {
  required bool allowTargetReversal,
}) {
  final sourceCentroid = _centroid(source);
  final targetCentroid = _centroid(target);
  final pointCount = source.length ~/ 2;
  final sourceEnergy = _pointEnergy(source, sourceCentroid);
  final targetEnergy = _pointEnergy(target, targetCentroid);
  if (sourceEnergy <= _energyEpsilon || targetEnergy <= _energyEpsilon) {
    return _Alignment(
      source: source,
      target: Float64List.fromList(target),
      sourceCentroid: sourceCentroid,
      targetCentroid: targetCentroid,
      similarity: _procrustesShifted(
        source,
        target,
        sourceCentroid,
        targetCentroid,
        reversed: false,
        offset: 0,
      ),
    );
  }
  final reversed =
      allowTargetReversal &&
      _signedPolygonArea(source) * _signedPolygonArea(target) < 0;
  final shortlist =
      pointCount >= _minimumFftAlignmentPointCount && _isPowerOfTwo(pointCount)
      ? _alignmentShortlist(
          _fftAlignmentScores(
            source,
            target,
            sourceCentroid,
            targetCentroid,
            sourceEnergy,
            targetEnergy,
            reversed: reversed,
          ),
        )
      : null;
  var bestScore = double.infinity;
  var bestOffset = 0;
  var bestSimilarity = const _Similarity(theta: 0, scale: 1, residual: 0);
  for (var offset = 0; offset < pointCount; offset++) {
    if (shortlist != null && shortlist[offset] == 0) {
      continue;
    }
    final similarity = _procrustesShifted(
      source,
      target,
      sourceCentroid,
      targetCentroid,
      reversed: reversed,
      offset: offset,
    );
    final score = _alignmentScore(similarity);
    if (score < bestScore) {
      bestScore = score;
      bestOffset = offset;
      bestSimilarity = similarity;
    }
  }
  return _Alignment(
    source: source,
    target: _orientedPoints(target, reversed: reversed, offset: bestOffset),
    sourceCentroid: sourceCentroid,
    targetCentroid: targetCentroid,
    similarity: bestSimilarity,
  );
}

Float64List _fftAlignmentScores(
  Float64List source,
  Float64List target,
  (double, double) sourceCentroid,
  (double, double) targetCentroid,
  double sourceEnergy,
  double targetEnergy, {
  required bool reversed,
}) {
  // Circular cross-correlation evaluates every ring offset in O(n log n).
  // The resulting shortlist is still verified by the exact Procrustes pass.
  final pointCount = source.length ~/ 2;
  final sourceSpectrum = _alignmentSpectrum(source, sourceCentroid);
  final targetSpectrum = _alignmentSpectrum(target, targetCentroid);
  final correlation = Float64List(2 * pointCount);
  final scores = Float64List(pointCount);
  final targetTransform = reversed
      ? targetSpectrum.reversed
      : targetSpectrum.forward;
  for (var frequency = 0; frequency < pointCount; frequency++) {
    final index = 2 * frequency;
    final sourceReal = sourceSpectrum.forward[index];
    final sourceImaginary = sourceSpectrum.forward[index + 1];
    final targetReal = targetTransform[index];
    final targetImaginary = targetTransform[index + 1];
    correlation[index] =
        sourceReal * targetReal + sourceImaginary * targetImaginary;
    correlation[index + 1] =
        sourceReal * targetImaginary - sourceImaginary * targetReal;
  }
  _fft(correlation, inverse: true);
  for (var offset = 0; offset < pointCount; offset++) {
    final index = 2 * offset;
    scores[offset] = _alignmentScore(
      _similarityFromCorrelation(
        correlation[index],
        correlation[index + 1],
        sourceEnergy,
        targetEnergy,
      ),
    );
  }
  return scores;
}

_CachedAlignmentSpectrum _alignmentSpectrum(
  Float64List points,
  (double, double) centroid,
) {
  final existing = _alignmentSpectrumCache[points];
  if (existing != null && _sameCoordinates(existing.points, points)) {
    return existing;
  }
  final spectrum = _CachedAlignmentSpectrum(points, centroid);
  _alignmentSpectrumCache[points] = spectrum;
  return spectrum;
}

bool _sameCoordinates(Float64List first, Float64List second) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}

Float64List _createPointSpectrum(
  Float64List points,
  (double, double) centroid, {
  required bool reversed,
}) {
  final pointCount = points.length ~/ 2;
  final spectrum = Float64List(points.length);
  for (var point = 0; point < pointCount; point++) {
    final sourcePoint = reversed ? pointCount - 1 - point : point;
    final index = 2 * point;
    final sourceIndex = 2 * sourcePoint;
    spectrum[index] = points[sourceIndex] - centroid.$1;
    spectrum[index + 1] = points[sourceIndex + 1] - centroid.$2;
  }
  _fft(spectrum, inverse: false);
  return spectrum;
}

Uint8List _alignmentShortlist(Float64List scores) {
  var bestScore = double.infinity;
  for (final score in scores) {
    if (score < bestScore) bestScore = score;
  }
  final selected = Uint8List(scores.length);
  for (var index = 0; index < scores.length; index++) {
    if (scores[index] <= bestScore + _alignmentScoreTolerance) {
      selected[index] = 1;
    }
  }
  return selected;
}

bool _isPowerOfTwo(int value) => value > 0 && (value & (value - 1)) == 0;

void _fft(Float64List values, {required bool inverse}) {
  // In-place iterative radix-2 Cooley-Tukey transform over interleaved complex
  // values. Repository contours use power-of-two counts, so no padding is
  // needed.
  final pointCount = values.length ~/ 2;
  for (var point = 1, reversed = 0; point < pointCount; point++) {
    var bit = pointCount >> 1;
    for (; (reversed & bit) != 0; bit >>= 1) {
      reversed ^= bit;
    }
    reversed ^= bit;
    if (point >= reversed) continue;
    final pointIndex = 2 * point;
    final reversedIndex = 2 * reversed;
    final real = values[pointIndex];
    final imaginary = values[pointIndex + 1];
    values[pointIndex] = values[reversedIndex];
    values[pointIndex + 1] = values[reversedIndex + 1];
    values[reversedIndex] = real;
    values[reversedIndex + 1] = imaginary;
  }

  for (var length = 2; length <= pointCount; length <<= 1) {
    final angle = (inverse ? 2 : -2) * math.pi / length;
    final stepReal = math.cos(angle);
    final stepImaginary = math.sin(angle);
    final half = length >> 1;
    for (var start = 0; start < pointCount; start += length) {
      var twiddleReal = 1.0;
      var twiddleImaginary = 0.0;
      for (var offset = 0; offset < half; offset++) {
        final evenIndex = 2 * (start + offset);
        final oddIndex = 2 * (start + offset + half);
        final oddReal =
            values[oddIndex] * twiddleReal -
            values[oddIndex + 1] * twiddleImaginary;
        final oddImaginary =
            values[oddIndex] * twiddleImaginary +
            values[oddIndex + 1] * twiddleReal;
        final evenReal = values[evenIndex];
        final evenImaginary = values[evenIndex + 1];
        values[evenIndex] = evenReal + oddReal;
        values[evenIndex + 1] = evenImaginary + oddImaginary;
        values[oddIndex] = evenReal - oddReal;
        values[oddIndex + 1] = evenImaginary - oddImaginary;
        final nextTwiddleReal =
            twiddleReal * stepReal - twiddleImaginary * stepImaginary;
        twiddleImaginary =
            twiddleReal * stepImaginary + twiddleImaginary * stepReal;
        twiddleReal = nextTwiddleReal;
      }
    }
  }

  if (!inverse) return;
  for (var index = 0; index < values.length; index++) {
    values[index] /= pointCount;
  }
}

MorphPlanItem _createItem(
  _Alignment alignment, {
  required bool sourceCollapsed,
  required bool targetCollapsed,
}) {
  final pointCount = alignment.source.length ~/ 2;
  final sourceCentered = Float64List(alignment.source.length);
  final targetInSourceFrame = Float64List(alignment.target.length);
  final orientedTarget = Float64List.fromList(alignment.target);
  final similarity = alignment.similarity;
  // A near-zero scale is meaningful for a good fit (for example, a contour
  // collapsing to a point). With an almost-total residual it instead divides
  // unrelated target points by a tiny number and explodes intermediate frames.
  final useSimilarity =
      similarity.scale >= _minimumStableSimilarityScale ||
      similarity.residual <= _maximumDegenerateSimilarityResidual;
  final theta = useSimilarity ? similarity.theta : 0.0;
  final scale = useSimilarity ? similarity.scale : 1.0;
  final inverseCosine = math.cos(-theta);
  final inverseSine = math.sin(-theta);
  for (var i = 0; i < pointCount; i++) {
    sourceCentered[2 * i] =
        alignment.source[2 * i] - alignment.sourceCentroid.$1;
    sourceCentered[2 * i + 1] =
        alignment.source[2 * i + 1] - alignment.sourceCentroid.$2;
    final targetX = alignment.target[2 * i] - alignment.targetCentroid.$1;
    final targetY = alignment.target[2 * i + 1] - alignment.targetCentroid.$2;
    targetInSourceFrame[2 * i] =
        (targetX * inverseCosine - targetY * inverseSine) / scale;
    targetInSourceFrame[2 * i + 1] =
        (targetX * inverseSine + targetY * inverseCosine) / scale;
  }
  return MorphPlanItem(
    source: Float64List.fromList(alignment.source),
    sourceCentered: sourceCentered,
    targetInSourceFrame: targetInSourceFrame,
    orientedTarget: orientedTarget,
    sourceCentroid: alignment.sourceCentroid,
    targetCentroid: alignment.targetCentroid,
    theta: theta,
    logScale: math.log(scale),
    residual: similarity.residual,
    sourceCollapsed: sourceCollapsed,
    targetCollapsed: targetCollapsed,
  );
}

void _applyGlobalAlignment(List<MorphPlanItem> items) {
  var sourceCenterX = 0.0;
  var sourceCenterY = 0.0;
  var targetCenterX = 0.0;
  var targetCenterY = 0.0;
  for (final item in items) {
    sourceCenterX += item.sourceCentroid.$1;
    sourceCenterY += item.sourceCentroid.$2;
    targetCenterX += item.targetCentroid.$1;
    targetCenterY += item.targetCentroid.$2;
  }
  final sourceCentroid = (
    sourceCenterX / items.length,
    sourceCenterY / items.length,
  );
  final targetCentroid = (
    targetCenterX / items.length,
    targetCenterY / items.length,
  );
  var dot = 0.0;
  var cross = 0.0;
  var sourceEnergy = 0.0;
  var targetEnergy = 0.0;
  for (final item in items) {
    final pointCount = item.source.length ~/ 2;
    final pointWeight = 1 / pointCount;
    for (var index = 0; index < item.source.length; index += 2) {
      final sourceX = item.source[index] - sourceCentroid.$1;
      final sourceY = item.source[index + 1] - sourceCentroid.$2;
      final targetX = item.orientedTarget[index] - targetCentroid.$1;
      final targetY = item.orientedTarget[index + 1] - targetCentroid.$2;
      dot += pointWeight * (sourceX * targetX + sourceY * targetY);
      cross += pointWeight * (sourceX * targetY - sourceY * targetX);
      sourceEnergy += pointWeight * (sourceX * sourceX + sourceY * sourceY);
      targetEnergy += pointWeight * (targetX * targetX + targetY * targetY);
    }
  }
  final global = _similarityFromCorrelation(
    dot,
    cross,
    sourceEnergy,
    targetEnergy,
  );
  if (global.residual >= _globalResidualThreshold) return;

  final inverseCosine = math.cos(-global.theta);
  final inverseSine = math.sin(-global.theta);
  final cosine = math.cos(global.theta);
  final sine = math.sin(global.theta);
  for (final item in items) {
    var squaredError = 0.0;
    var targetEnergy = 0.0;
    for (var i = 0; i < item.source.length; i += 2) {
      final targetX = item.orientedTarget[i] - item.targetCentroid.$1;
      final targetY = item.orientedTarget[i + 1] - item.targetCentroid.$2;
      item.targetInSourceFrame[i] =
          (targetX * inverseCosine - targetY * inverseSine) / global.scale;
      item.targetInSourceFrame[i + 1] =
          (targetX * inverseSine + targetY * inverseCosine) / global.scale;
      final errorX =
          global.scale *
              (cosine * item.sourceCentered[i] -
                  sine * item.sourceCentered[i + 1]) -
          targetX;
      final errorY =
          global.scale *
              (sine * item.sourceCentered[i] +
                  cosine * item.sourceCentered[i + 1]) -
          targetY;
      squaredError += errorX * errorX + errorY * errorY;
      targetEnergy += targetX * targetX + targetY * targetY;
    }
    item.theta = global.theta;
    item.logScale = math.log(global.scale);
    item.residual = targetEnergy > _energyEpsilon
        ? math.sqrt(squaredError / targetEnergy)
        : 0;
    final offsetX = item.sourceCentroid.$1 - sourceCentroid.$1;
    final offsetY = item.sourceCentroid.$2 - sourceCentroid.$2;
    final scaledCosine = math.cos(item.theta) * math.exp(item.logScale);
    final scaledSine = math.sin(item.theta) * math.exp(item.logScale);
    final rotatedX = offsetX * scaledCosine - offsetY * scaledSine - offsetX;
    final rotatedY = offsetX * scaledSine + offsetY * scaledCosine - offsetY;
    item.blockOffset = (offsetX, offsetY);
    item.blockDrift = (
      item.targetCentroid.$1 - item.sourceCentroid.$1 - rotatedX,
      item.targetCentroid.$2 - item.sourceCentroid.$2 - rotatedY,
    );
  }
}

void _interpolateItem(MorphPlanItem item, double t, Float64List output) {
  final scale = math.exp(item.logScale * t);
  final angle = item.theta * t;
  final cosine = math.cos(angle) * scale;
  final sine = math.sin(angle) * scale;
  late final double centerX;
  late final double centerY;
  if (item.blockOffset case final offset?) {
    final drift = item.blockDrift!;
    centerX =
        item.sourceCentroid.$1 +
        drift.$1 * t +
        (offset.$1 * cosine - offset.$2 * sine - offset.$1);
    centerY =
        item.sourceCentroid.$2 +
        drift.$2 * t +
        (offset.$1 * sine + offset.$2 * cosine - offset.$2);
  } else {
    centerX =
        item.sourceCentroid.$1 +
        (item.targetCentroid.$1 - item.sourceCentroid.$1) * t;
    centerY =
        item.sourceCentroid.$2 +
        (item.targetCentroid.$2 - item.sourceCentroid.$2) * t;
  }
  for (var i = 0; i < output.length; i += 2) {
    final x =
        item.sourceCentered[i] +
        (item.targetInSourceFrame[i] - item.sourceCentered[i]) * t;
    final y =
        item.sourceCentered[i + 1] +
        (item.targetInSourceFrame[i + 1] - item.sourceCentered[i + 1]) * t;
    output[i] = centerX + x * cosine - y * sine;
    output[i + 1] = centerY + x * sine + y * cosine;
  }
}

_Similarity _procrustesShifted(
  Float64List source,
  Float64List target,
  (double, double) sourceCentroid,
  (double, double) targetCentroid, {
  required bool reversed,
  required int offset,
}) {
  var xx = 0.0;
  var xy = 0.0;
  var yx = 0.0;
  var yy = 0.0;
  var sourceEnergy = 0.0;
  var targetEnergy = 0.0;
  final pointCount = source.length ~/ 2;
  var targetPoint = reversed ? pointCount - 1 - offset : offset;
  for (var sourcePoint = 0; sourcePoint < pointCount; sourcePoint++) {
    final sourceIndex = 2 * sourcePoint;
    final targetIndex = 2 * targetPoint;
    final sourceX = source[sourceIndex] - sourceCentroid.$1;
    final sourceY = source[sourceIndex + 1] - sourceCentroid.$2;
    final targetX = target[targetIndex] - targetCentroid.$1;
    final targetY = target[targetIndex + 1] - targetCentroid.$2;
    xx += sourceX * targetX;
    xy += sourceX * targetY;
    yx += sourceY * targetX;
    yy += sourceY * targetY;
    sourceEnergy += sourceX * sourceX + sourceY * sourceY;
    targetEnergy += targetX * targetX + targetY * targetY;
    if (reversed) {
      targetPoint = targetPoint == 0 ? pointCount - 1 : targetPoint - 1;
    } else {
      targetPoint = targetPoint + 1 == pointCount ? 0 : targetPoint + 1;
    }
  }
  return _similarityFromCorrelation(
    xx + yy,
    xy - yx,
    sourceEnergy,
    targetEnergy,
  );
}

_Similarity _similarityFromCorrelation(
  double dot,
  double cross,
  double sourceEnergy,
  double targetEnergy,
) {
  final theta = math.atan2(cross, dot);
  final numerator = math.cos(theta) * dot + math.sin(theta) * cross;
  var scale = sourceEnergy > _energyEpsilon ? numerator / sourceEnergy : 1.0;
  if (!(scale > _minimumScale)) scale = _minimumScale;
  final squaredResidual = math.max(
    0,
    scale * scale * sourceEnergy - 2 * scale * numerator + targetEnergy,
  );
  final residual = targetEnergy > _energyEpsilon
      ? math.sqrt(squaredResidual / targetEnergy)
      : 0.0;
  return _Similarity(theta: theta, scale: scale, residual: residual);
}

double _alignmentScore(_Similarity similarity) =>
    similarity.residual + _rotationTieBreak * similarity.theta.abs() / math.pi;

double _pointEnergy(Float64List points, (double, double) centroid) {
  var energy = 0.0;
  for (var index = 0; index < points.length; index += 2) {
    final x = points[index] - centroid.$1;
    final y = points[index + 1] - centroid.$2;
    energy += x * x + y * y;
  }
  return energy;
}

(double, double) _centroid(Float64List points) {
  var x = 0.0;
  var y = 0.0;
  for (var i = 0; i < points.length; i += 2) {
    x += points[i];
    y += points[i + 1];
  }
  final count = points.length ~/ 2;
  return (x / count, y / count);
}

double _polygonLength(Float64List points) {
  var length = 0.0;
  final pointCount = points.length ~/ 2;
  for (var i = 0; i < pointCount; i++) {
    final next = (i + 1) % pointCount;
    length += math.sqrt(
      math.pow(points[2 * next] - points[2 * i], 2) +
          math.pow(points[2 * next + 1] - points[2 * i + 1], 2),
    );
  }
  return length;
}

double _signedPolygonArea(Float64List points) {
  var twiceArea = 0.0;
  final pointCount = points.length ~/ 2;
  for (var point = 0; point < pointCount; point++) {
    final next = point + 1 == pointCount ? 0 : point + 1;
    twiceArea +=
        points[2 * point] * points[2 * next + 1] -
        points[2 * next] * points[2 * point + 1];
  }
  return twiceArea / 2;
}

double _distance((double, double) a, (double, double) b) =>
    math.sqrt(math.pow(a.$1 - b.$1, 2) + math.pow(a.$2 - b.$2, 2));

Float64List _orientedPoints(
  Float64List points, {
  required bool reversed,
  required int offset,
}) {
  final pointCount = points.length ~/ 2;
  final output = Float64List(points.length);
  var sourcePoint = reversed ? pointCount - 1 - offset : offset;
  for (var targetPoint = 0; targetPoint < pointCount; targetPoint++) {
    output[2 * targetPoint] = points[2 * sourcePoint];
    output[2 * targetPoint + 1] = points[2 * sourcePoint + 1];
    if (reversed) {
      sourcePoint = sourcePoint == 0 ? pointCount - 1 : sourcePoint - 1;
    } else {
      sourcePoint = sourcePoint + 1 == pointCount ? 0 : sourcePoint + 1;
    }
  }
  return output;
}

final class _CachedAlignmentSpectrum {
  _CachedAlignmentSpectrum(Float64List points, this.centroid)
    : points = Float64List.fromList(points),
      forward = _createPointSpectrum(points, centroid, reversed: false);

  final Float64List points;
  final (double, double) centroid;
  final Float64List forward;
  Float64List? _reversed;

  Float64List get reversed =>
      _reversed ??= _createPointSpectrum(points, centroid, reversed: true);
}

final class _Alignment {
  const _Alignment({
    required this.source,
    required this.target,
    required this.sourceCentroid,
    required this.targetCentroid,
    required this.similarity,
  });

  final Float64List source;
  final Float64List target;
  final (double, double) sourceCentroid;
  final (double, double) targetCentroid;
  final _Similarity similarity;
}

final class _Similarity {
  const _Similarity({
    required this.theta,
    required this.scale,
    required this.residual,
  });

  final double theta;
  final double scale;
  final double residual;
}
