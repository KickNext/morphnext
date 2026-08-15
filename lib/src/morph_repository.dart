import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'cache/sized_lru_cache.dart';
import 'font/font_asset_resolver.dart';
import 'font/font_selection.dart';
import 'geometry/morph_plan.dart';
import 'geometry/resample.dart';
import 'geometry/shape.dart';

const _maximumCachedShapes = 256;
const _maximumRetainedShapeBytes = 8 << 20;
const _maximumCachedPlans = 128;
const _maximumRetainedPlanBytes = 16 << 20;
const _minimumContourPointCount = 64;
const _maximumContourPointCount = 2048;
const _samplesPerCubicSegment = 16;
typedef _ShapeCacheKey = (IconData, TextDirection, MorphFontSelection);
typedef _PlanCacheKey = (IconData, IconData, TextDirection, MorphFontSelection);

/// Extracts, normalizes, and caches morph geometry for one asset bundle.
final class MorphRepository {
  MorphRepository._(this.resolver);

  static final Expando<MorphRepository> _repositories =
      Expando<MorphRepository>('morphnext repositories');

  static MorphRepository forBundle(AssetBundle bundle) {
    final existing = _repositories[bundle];
    if (existing != null) return existing;
    final repository = MorphRepository._(FontAssetResolver(bundle));
    _repositories[bundle] = repository;
    return repository;
  }

  final FontAssetResolver resolver;
  final SizedLruCache<_ShapeCacheKey, Future<MorphShape>> _shapes =
      SizedLruCache<_ShapeCacheKey, Future<MorphShape>>(
        maximumSize: _maximumCachedShapes,
        maximumSizeBytes: _maximumRetainedShapeBytes,
      );
  final SizedLruCache<_PlanCacheKey, Future<MorphPlan>> _plans =
      SizedLruCache<_PlanCacheKey, Future<MorphPlan>>(
        maximumSize: _maximumCachedPlans,
        maximumSizeBytes: _maximumRetainedPlanBytes,
      );

  Future<MorphShape> shapeFor(
    IconData icon,
    TextDirection direction, [
    MorphFontSelection fontSelection = defaultMorphFontSelection,
  ]) {
    final key = (icon, direction, fontSelection);
    final existing = _shapes.get(key);
    if (existing != null) return existing;
    late final Future<MorphShape> future;
    future = () async {
      try {
        final shape = await _createShape(icon, direction, fontSelection);
        _shapes.updateSizeIfSame(key, future, _shapeBytes(shape));
        return shape;
      } catch (_) {
        _shapes.removeIfSame(key, future);
        rethrow;
      }
    }();
    _shapes.put(key, future);
    return future;
  }

  Future<MorphPlan> planFor(
    IconData from,
    IconData to,
    TextDirection direction, [
    MorphFontSelection fontSelection = defaultMorphFontSelection,
  ]) {
    final key = (from, to, direction, fontSelection);
    final existing = _plans.get(key);
    if (existing != null) return existing;
    late final Future<MorphPlan> future;
    future = () async {
      try {
        final shapes = await Future.wait<MorphShape>(<Future<MorphShape>>[
          shapeFor(from, direction, fontSelection),
          shapeFor(to, direction, fontSelection),
        ]);
        final plan = buildMorphPlan(shapes[0], shapes[1]);
        _plans.updateSizeIfSame(key, future, _planBytes(plan));
        return plan;
      } catch (_) {
        _plans.removeIfSame(key, future);
        rethrow;
      }
    }();
    _plans.put(key, future);
    return future;
  }

  Future<MorphPlan> planFromShape(
    MorphShape source,
    IconData to,
    TextDirection direction, [
    MorphFontSelection fontSelection = defaultMorphFontSelection,
  ]) async =>
      buildMorphPlan(source, await shapeFor(to, direction, fontSelection));

  Future<MorphShape> _createShape(
    IconData icon,
    TextDirection direction,
    MorphFontSelection fontSelection,
  ) async {
    final outline = await resolver.resolve(icon, fontSelection);
    final unitsPerEm = outline.metrics.unitsPerEm;
    if (unitsPerEm <= 0 || outline.contours.isEmpty) {
      throw const FormatException('Icon glyph has no normalizable outline');
    }
    final leading =
        unitsPerEm - (outline.metrics.ascender - outline.metrics.descender);
    // Flutter's Icon centers the laid-out RichText only while its intrinsic
    // advance fits inside the square icon box. Wider glyphs are constrained
    // to the box width and overflow from x=0 instead of being centered with a
    // negative offset (common for Font Awesome brand wordmarks).
    final horizontalOffset = outline.advanceWidth < unitsPerEm
        ? (unitsPerEm - outline.advanceWidth) / 2
        : 0.0;
    final mirror = direction == TextDirection.rtl && icon.matchTextDirection;
    final normalized = <CubicContour>[];
    for (final contour in outline.contours) {
      final source = contour.points;
      final points = Float64List(source.length);
      for (var index = 0; index < source.length; index += 2) {
        var normalizedX = (source[index] + horizontalOffset) / unitsPerEm;
        final normalizedY =
            (leading / 2 + outline.metrics.ascender - source[index + 1]) /
            unitsPerEm;
        if (mirror) normalizedX = 1 - normalizedX;
        if (!normalizedX.isFinite || !normalizedY.isFinite) {
          throw const FormatException('Non-finite normalized glyph point');
        }
        points[index] = normalizedX;
        points[index + 1] = normalizedY;
      }
      normalized.add(CubicContour(points));
    }
    final shape = sampleContoursWithPointCounts(
      normalized,
      pointCounts: <int>[
        for (final contour in normalized) _pointCountFor(contour),
      ],
      fillRule: MorphFillRule.nonZero,
    );
    if (shape.contours.isEmpty) {
      throw const FormatException('Icon glyph sampled to an empty shape');
    }
    return shape;
  }
}

int _pointCountFor(CubicContour contour) {
  final required = contour.segmentCount * _samplesPerCubicSegment;
  var pointCount = _minimumContourPointCount;
  while (pointCount < required && pointCount < _maximumContourPointCount) {
    pointCount *= 2;
  }
  return pointCount;
}

int _shapeBytes(MorphShape shape) =>
    shape.contours.fold<int>(
      0,
      (total, contour) => total + contour.points.lengthInBytes,
    ) +
    (shape.exactContours?.fold<int>(
          0,
          (total, contour) => total + contour.points.lengthInBytes,
        ) ??
        0);

int _planBytes(MorphPlan plan) => plan.items.fold<int>(
  0,
  (total, item) =>
      total +
      item.source.lengthInBytes +
      item.sourceCentered.lengthInBytes +
      item.targetInSourceFrame.lengthInBytes +
      item.orientedTarget.lengthInBytes,
);
