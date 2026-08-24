import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../cache/sized_lru_cache.dart';
import 'binary_reader.dart';
import 'font_selection.dart';
import 'open_type_font.dart';

const _maximumCachedGlyphs = 256;
const _maximumRetainedGlyphBytes = 8 << 20;
typedef _GlyphCacheKey = (IconData, String, MorphFontSelection);

/// Resolves bundled [IconData] through Flutter's font manifest.
final class FontAssetResolver {
  FontAssetResolver(this.bundle);

  final AssetBundle bundle;
  Future<List<_ManifestFamily>>? _manifest;
  final Map<String, Future<OpenTypeFont>> _fonts =
      <String, Future<OpenTypeFont>>{};
  final SizedLruCache<_GlyphCacheKey, Future<GlyphOutline>> _glyphs =
      SizedLruCache<_GlyphCacheKey, Future<GlyphOutline>>(
        maximumSize: _maximumCachedGlyphs,
        maximumSizeBytes: _maximumRetainedGlyphBytes,
      );

  /// Clears all manifest, font, and glyph data retained by this resolver.
  void clear() {
    _manifest = null;
    _fonts.clear();
    _glyphs.clear();
  }

  Future<GlyphOutline> resolve(
    IconData icon, [
    MorphFontSelection selection = defaultMorphFontSelection,
  ]) {
    final families = _familiesFor(icon);
    final key = (icon, families.join('\u0000'), selection);
    final existing = _glyphs.get(key);
    if (existing != null) return _awaitGlyph(key, existing);
    final future = _resolve(icon, families, selection);
    _glyphs.put(key, future);
    return _awaitGlyph(key, future);
  }

  Future<GlyphOutline> _awaitGlyph(
    _GlyphCacheKey key,
    Future<GlyphOutline> future,
  ) async {
    try {
      final glyph = await future;
      _glyphs.updateSizeIfSame(
        key,
        future,
        glyph.contours.fold<int>(
          0,
          (total, contour) => total + contour.points.lengthInBytes,
        ),
      );
      return glyph;
    } catch (_) {
      _glyphs.removeIfSame(key, future);
      rethrow;
    }
  }

  Future<GlyphOutline> _resolve(
    IconData icon,
    List<String> families,
    MorphFontSelection selection,
  ) async {
    final manifest = await _loadManifest();
    Object? lastFailure;
    for (final requestedFamily in families) {
      for (final manifestFamily in manifest) {
        if (manifestFamily.name != requestedFamily) continue;
        for (final face in manifestFamily.facesFor(selection.fontWeight)) {
          try {
            final font = await _loadFont(face.asset);
            if (!font.containsCodePoint(icon.codePoint)) continue;
            return font.glyphForCodePoint(icon.codePoint, (
              fill: selection.fill,
              weight: selection.weight,
              grade: selection.grade,
              opticalSize: selection.opticalSize,
            ));
          } catch (error) {
            lastFailure = FontDataException(
              'Failed to read bundled font face',
              assetKey: face.asset,
              cause: error,
            );
          }
        }
      }
    }
    throw FontDataException(
      'No bundled font face contains $icon',
      cause: lastFailure,
    );
  }

  List<String> _familiesFor(IconData icon) {
    final rawFamilies = <String>[?icon.fontFamily, ...?icon.fontFamilyFallback];
    if (rawFamilies.isEmpty) {
      throw const FontDataException('IconData has no font family');
    }
    final package = icon.fontPackage;
    return <String>[
      for (final family in rawFamilies)
        if (package == null) family else 'packages/$package/$family',
    ];
  }

  Future<List<_ManifestFamily>> _loadManifest() async {
    final existing = _manifest;
    if (existing != null) return _awaitManifest(existing);
    final future = _readManifest();
    _manifest = future;
    return _awaitManifest(future);
  }

  Future<List<_ManifestFamily>> _awaitManifest(
    Future<List<_ManifestFamily>> future,
  ) async {
    try {
      return await future;
    } catch (_) {
      if (identical(_manifest, future)) _manifest = null;
      rethrow;
    }
  }

  Future<List<_ManifestFamily>> _readManifest() async {
    try {
      final decoded = jsonDecode(
        await bundle.loadString('FontManifest.json', cache: false),
      );
      if (decoded is! List) {
        throw const FormatException('Expected a JSON list');
      }
      final families = <_ManifestFamily>[];
      for (final entry in decoded) {
        if (entry is! Map) {
          throw const FormatException('Expected a font family object');
        }
        final family = entry['family'];
        final fonts = entry['fonts'];
        if (family is! String || fonts is! List) {
          throw const FormatException('Invalid font family entry');
        }
        final faces = <_ManifestFace>[];
        for (final face in fonts) {
          if (face is! Map || face['asset'] is! String) {
            throw const FormatException('Invalid font face entry');
          }
          final weight = face['weight'];
          if (weight != null && weight is! int) {
            throw const FormatException('Invalid font face weight');
          }
          faces.add(
            _ManifestFace(
              face['asset'] as String,
              weight: weight as int? ?? 400,
            ),
          );
        }
        families.add(_ManifestFamily(family, faces));
      }
      return List<_ManifestFamily>.unmodifiable(families);
    } catch (error) {
      if (error is FontDataException) rethrow;
      throw FontDataException('Invalid FontManifest.json', cause: error);
    }
  }

  Future<OpenTypeFont> _loadFont(String assetKey) async {
    var future = _fonts[assetKey];
    if (future == null) {
      future = _readFont(assetKey);
      _fonts[assetKey] = future;
    }
    try {
      return await future;
    } catch (_) {
      if (identical(_fonts[assetKey], future)) {
        _fonts.remove(assetKey);
      }
      rethrow;
    }
  }

  Future<OpenTypeFont> _readFont(String assetKey) async {
    final data = await bundle.load(assetKey);
    final bytes = Uint8List.sublistView(
      data.buffer.asUint8List(),
      data.offsetInBytes,
      data.offsetInBytes + data.lengthInBytes,
    );
    return OpenTypeFont.parse(bytes);
  }
}

final class _ManifestFamily {
  _ManifestFamily(this.name, List<_ManifestFace> faces)
    : _faces = List<_ManifestFace>.unmodifiable(faces);

  final String name;
  final List<_ManifestFace> _faces;

  List<_ManifestFace> facesFor(FontWeight? requested) {
    if (requested == null) return _faces;
    final target = requested.value;
    return List<_ManifestFace>.of(_faces)..sort((a, b) {
      final comparison = (a.weight - target).abs().compareTo(
        (b.weight - target).abs(),
      );
      return comparison == 0
          ? _faces.indexOf(a).compareTo(_faces.indexOf(b))
          : comparison;
    });
  }
}

final class _ManifestFace {
  const _ManifestFace(this.asset, {required this.weight});

  final String asset;
  final int weight;
}
