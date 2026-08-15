import 'dart:typed_data';

import '../geometry/shape.dart';
import 'binary_reader.dart';
import 'cff_outline.dart';
import 'font_selection.dart';
import 'true_type_outline.dart';

const _trueTypeScaler = 0x00010000;
const _openTypeScaler = 0x4f54544f;
const _legacyTrueScaler = 0x74727565;
const _legacyType1Scaler = 0x74797031;
const _collectionScaler = 0x74746366;
const _useTypoMetrics = 0x0080;

/// Outline storage used by an OpenType font.
enum OutlineFormat { trueType, cff1 }

/// One design axis declared by an OpenType `fvar` table.
final class FontVariationAxis {
  const FontVariationAxis({
    required this.tag,
    required this.minimum,
    required this.defaultValue,
    required this.maximum,
  });

  final String tag;
  final double minimum;
  final double defaultValue;
  final double maximum;
}

/// Metrics required to place a glyph like Flutter's height-one icon text.
final class FontMetrics {
  /// Creates immutable font metrics.
  const FontMetrics({
    required this.unitsPerEm,
    required this.ascender,
    required this.descender,
  });

  /// Font design units per em.
  final int unitsPerEm;

  /// Typographic ascender in design units.
  final int ascender;

  /// Typographic descender in design units.
  final int descender;
}

/// One decoded glyph outline and the metrics used to position it.
final class GlyphOutline {
  /// Creates a glyph outline.
  GlyphOutline({
    required List<CubicContour> contours,
    required this.advanceWidth,
    required this.metrics,
  }) : contours = List<CubicContour>.unmodifiable(contours);

  /// Closed cubic contours in font coordinates.
  final List<CubicContour> contours;

  /// Horizontal advance in design units.
  final int advanceWidth;

  /// Parent font metrics.
  final FontMetrics metrics;
}

/// A lazily indexed SFNT font containing TrueType or CFF1 outlines.
final class OpenTypeFont {
  OpenTypeFont._({
    required this.bytes,
    required Map<String, BinaryReader> tables,
    required List<_CmapSubtable> cmaps,
    required this.metrics,
    required this.outlineFormat,
    required this.numGlyphs,
    required this.numberOfHMetrics,
    required this.indexToLocFormat,
    required Map<String, FontVariationAxis> variationAxes,
    required List<List<(double, double)>> axisMappings,
  }) : _tables = Map<String, BinaryReader>.unmodifiable(tables),
       _cmaps = List<_CmapSubtable>.unmodifiable(cmaps),
       variationAxes = Map<String, FontVariationAxis>.unmodifiable(
         variationAxes,
       ),
       _axisMappings = List<List<(double, double)>>.unmodifiable(axisMappings);

  /// Parses and indexes an SFNT font.
  factory OpenTypeFont.parse(Uint8List input) {
    if (input.length > maxFontByteLength) {
      throw const FontDataException('Font exceeds the 64 MiB limit');
    }
    final bytes = Uint8List.fromList(input);
    final reader = BinaryReader(bytes)..require(0, 12);
    final scaler = reader.uint32(0);
    if (scaler == _collectionScaler) {
      throw const FontDataException('TrueType collections are unsupported');
    }
    if (scaler != _trueTypeScaler &&
        scaler != _openTypeScaler &&
        scaler != _legacyTrueScaler &&
        scaler != _legacyType1Scaler) {
      throw const FontDataException('Unsupported SFNT scaler type');
    }

    final tableCount = reader.uint16(4);
    if (tableCount == 0 || tableCount > maxSfntTableCount) {
      throw FontDataException('Invalid SFNT table count: $tableCount');
    }
    reader.require(12, 16 * tableCount);
    final tables = <String, BinaryReader>{};
    for (var index = 0; index < tableCount; index++) {
      final recordOffset = 12 + 16 * index;
      final tag = reader.tag(recordOffset);
      final offset = reader.uint32(recordOffset + 8);
      final length = reader.uint32(recordOffset + 12);
      if (tables.containsKey(tag)) {
        throw FontDataException('Duplicate SFNT table', tableTag: tag);
      }
      try {
        tables[tag] = reader.slice(offset, length);
      } on FontDataException catch (error) {
        throw FontDataException(
          'SFNT table is outside font data',
          tableTag: tag,
          cause: error,
        );
      }
    }

    BinaryReader requiredTable(String tag) {
      final table = tables[tag];
      if (table == null) {
        throw FontDataException(
          'Required SFNT table is missing',
          tableTag: tag,
        );
      }
      return table;
    }

    if (tables.containsKey('CFF2')) {
      throw const FontDataException(
        'CFF2 variable outlines are unsupported',
        tableTag: 'CFF2',
      );
    }
    final hasTrueType =
        tables.containsKey('glyf') || tables.containsKey('loca');
    if (tables.containsKey('glyf') != tables.containsKey('loca')) {
      throw const FontDataException('TrueType outlines require glyf and loca');
    }
    final hasCff = tables.containsKey('CFF ');
    if (hasTrueType == hasCff) {
      throw const FontDataException(
        'Font must contain exactly one supported outline format',
      );
    }
    final outlineFormat = hasTrueType
        ? OutlineFormat.trueType
        : OutlineFormat.cff1;

    final head = requiredTable('head')..require(0, 54);
    final unitsPerEm = head.uint16(18);
    if (unitsPerEm < 16 || unitsPerEm > 16384) {
      throw const FontDataException('Invalid unitsPerEm', tableTag: 'head');
    }
    final indexToLocFormat = head.int16(50);
    if (outlineFormat == OutlineFormat.trueType &&
        indexToLocFormat != 0 &&
        indexToLocFormat != 1) {
      throw const FontDataException(
        'Invalid indexToLocFormat',
        tableTag: 'head',
      );
    }

    final maxp = requiredTable('maxp')..require(0, 6);
    final numGlyphs = maxp.uint16(4);
    if (numGlyphs == 0) {
      throw const FontDataException(
        'Font contains no glyphs',
        tableTag: 'maxp',
      );
    }

    final hhea = requiredTable('hhea')..require(0, 36);
    final numberOfHMetrics = hhea.uint16(34);
    if (numberOfHMetrics == 0 || numberOfHMetrics > numGlyphs) {
      throw const FontDataException(
        'Invalid horizontal metric count',
        tableTag: 'hhea',
      );
    }
    final requiredHmtxLength =
        4 * numberOfHMetrics + 2 * (numGlyphs - numberOfHMetrics);
    requiredTable('hmtx').require(0, requiredHmtxLength);

    final cmaps = _parseCmaps(requiredTable('cmap'));
    if (cmaps.isEmpty) {
      throw const FontDataException(
        'No supported Unicode cmap',
        tableTag: 'cmap',
      );
    }
    final metrics = _fontMetrics(
      unitsPerEm: unitsPerEm,
      hhea: hhea,
      os2: tables['OS/2'],
    );
    final variationAxes = _parseVariationAxes(tables['fvar']);
    final axisMappings = _parseAxisMappings(
      tables['avar'],
      variationAxes.length,
    );

    return OpenTypeFont._(
      bytes: bytes,
      tables: tables,
      cmaps: cmaps,
      metrics: metrics,
      outlineFormat: outlineFormat,
      numGlyphs: numGlyphs,
      numberOfHMetrics: numberOfHMetrics,
      indexToLocFormat: indexToLocFormat,
      variationAxes: variationAxes,
      axisMappings: axisMappings,
    );
  }

  /// Immutable font bytes retained by this index.
  final Uint8List bytes;
  final Map<String, BinaryReader> _tables;
  final List<_CmapSubtable> _cmaps;

  /// Core font metrics.
  final FontMetrics metrics;

  /// Outline storage selected during parsing.
  final OutlineFormat outlineFormat;

  /// Number of glyph slots in the font.
  final int numGlyphs;

  /// Number of full records in `hmtx`.
  final int numberOfHMetrics;

  /// TrueType `loca` encoding, 0 for short and 1 for long.
  final int indexToLocFormat;

  /// Design axes declared by the optional `fvar` table, keyed by tag.
  final Map<String, FontVariationAxis> variationAxes;
  final List<List<(double, double)>> _axisMappings;

  /// Finds the glyph id for a Unicode scalar value.
  int? glyphIndexForCodePoint(int codePoint) {
    if (codePoint < 0 ||
        codePoint > 0x10ffff ||
        codePoint >= 0xd800 && codePoint <= 0xdfff) {
      return null;
    }
    for (final cmap in _cmaps) {
      final glyph = cmap.lookup(codePoint);
      if (glyph == null) continue;
      if (glyph >= numGlyphs) {
        throw FontDataException(
          'cmap references glyph $glyph beyond $numGlyphs glyphs',
          tableTag: 'cmap',
        );
      }
      return glyph;
    }
    return null;
  }

  /// Whether this font contains a non-notdef glyph for [codePoint].
  bool containsCodePoint(int codePoint) =>
      glyphIndexForCodePoint(codePoint) != null;

  /// Returns a glyph's horizontal advance.
  int advanceWidth(int glyphId) {
    if (glyphId < 0 || glyphId >= numGlyphs) {
      throw FontDataException('Invalid glyph id: $glyphId', glyphId: glyphId);
    }
    final hmtx = requiredTable('hmtx');
    final metricIndex = glyphId < numberOfHMetrics
        ? glyphId
        : numberOfHMetrics - 1;
    return hmtx.uint16(4 * metricIndex);
  }

  /// Returns a required table slice for an outline decoder.
  BinaryReader requiredTable(String tag) {
    final table = _tables[tag];
    if (table == null) {
      throw FontDataException('Required SFNT table is missing', tableTag: tag);
    }
    return table;
  }

  /// Returns an optional font table.
  BinaryReader? table(String tag) => _tables[tag];

  /// Converts user-space axis values into ordered normalized coordinates.
  List<double> normalizedVariationCoordinates(Map<String, double> coordinates) {
    final result = <double>[];
    var index = 0;
    for (final axis in variationAxes.values) {
      final value = (coordinates[axis.tag] ?? axis.defaultValue).clamp(
        axis.minimum,
        axis.maximum,
      );
      var normalized = value == axis.defaultValue
          ? 0.0
          : value < axis.defaultValue
          ? -(axis.defaultValue - value) / (axis.defaultValue - axis.minimum)
          : (value - axis.defaultValue) / (axis.maximum - axis.defaultValue);
      final mapping = _axisMappings[index++];
      for (var segment = 1; segment < mapping.length; segment++) {
        final previous = mapping[segment - 1];
        final next = mapping[segment];
        if (normalized > next.$1) continue;
        final span = next.$1 - previous.$1;
        normalized = span == 0
            ? previous.$2
            : previous.$2 +
                  (normalized - previous.$1) * (next.$2 - previous.$2) / span;
        break;
      }
      result.add(normalized.clamp(-1.0, 1.0));
    }
    return result;
  }

  /// Decodes the outline mapped from [codePoint].
  GlyphOutline glyphForCodePoint(
    int codePoint, [
    MorphFontSelection selection = defaultMorphFontSelection,
  ]) {
    final glyphId = glyphIndexForCodePoint(codePoint);
    if (glyphId == null) {
      throw FontDataException(
        'Code point U+${codePoint.toRadixString(16)} is absent',
      );
    }
    return switch (outlineFormat) {
      OutlineFormat.trueType => readTrueTypeGlyph(
        this,
        glyphId,
        variationCoordinates: _variationCoordinates(selection),
      ),
      OutlineFormat.cff1 => readCff1Glyph(this, glyphId),
    };
  }

  Map<String, double> _variationCoordinates(MorphFontSelection selection) {
    final requested = <String, double?>{
      'FILL': selection.fill,
      'wght': selection.weight,
      'GRAD': selection.grade,
      'opsz': selection.opticalSize,
    };
    return <String, double>{
      for (final entry in requested.entries)
        if (entry.value != null && variationAxes.containsKey(entry.key))
          entry.key: entry.value!.clamp(
            variationAxes[entry.key]!.minimum,
            variationAxes[entry.key]!.maximum,
          ),
    };
  }
}

Map<String, FontVariationAxis> _parseVariationAxes(BinaryReader? fvar) {
  if (fvar == null) return const <String, FontVariationAxis>{};
  fvar.require(0, 16);
  if (fvar.uint16(0) != 1) {
    throw const FontDataException('Unsupported fvar version', tableTag: 'fvar');
  }
  final axesOffset = fvar.uint16(4);
  final axisCount = fvar.uint16(8);
  final axisSize = fvar.uint16(10);
  if (axisSize < 20 || axisCount > 64) {
    throw const FontDataException('Invalid fvar axes', tableTag: 'fvar');
  }
  fvar.require(axesOffset, axisCount * axisSize);
  final result = <String, FontVariationAxis>{};
  for (var index = 0; index < axisCount; index++) {
    final offset = axesOffset + index * axisSize;
    final tag = fvar.tag(offset);
    final minimum = fvar.int32(offset + 4) / 65536;
    final defaultValue = fvar.int32(offset + 8) / 65536;
    final maximum = fvar.int32(offset + 12) / 65536;
    if (!(minimum <= defaultValue && defaultValue <= maximum)) {
      throw const FontDataException(
        'Invalid fvar axis range',
        tableTag: 'fvar',
      );
    }
    if (result.containsKey(tag)) {
      throw const FontDataException('Duplicate fvar axis', tableTag: 'fvar');
    }
    result[tag] = FontVariationAxis(
      tag: tag,
      minimum: minimum,
      defaultValue: defaultValue,
      maximum: maximum,
    );
  }
  return result;
}

List<List<(double, double)>> _parseAxisMappings(
  BinaryReader? avar,
  int axisCount,
) {
  if (axisCount == 0) return const <List<(double, double)>>[];
  if (avar == null) {
    return List<List<(double, double)>>.generate(
      axisCount,
      (_) => const <(double, double)>[(-1, -1), (0, 0), (1, 1)],
      growable: false,
    );
  }
  avar.require(0, 8);
  if (avar.uint16(0) != 1 || avar.uint16(6) != axisCount) {
    throw const FontDataException('Invalid avar header', tableTag: 'avar');
  }
  var cursor = 8;
  final result = <List<(double, double)>>[];
  for (var axis = 0; axis < axisCount; axis++) {
    final count = avar.uint16(cursor);
    cursor += 2;
    avar.require(cursor, 4 * count);
    final mapping = <(double, double)>[];
    for (var index = 0; index < count; index++) {
      mapping.add((avar.f2Dot14(cursor), avar.f2Dot14(cursor + 2)));
      cursor += 4;
    }
    final valid =
        mapping.length >= 3 &&
        mapping.first == const (-1.0, -1.0) &&
        mapping.contains(const (0.0, 0.0)) &&
        mapping.last == const (1.0, 1.0);
    result.add(
      valid
          ? List<(double, double)>.unmodifiable(mapping)
          : const <(double, double)>[(-1, -1), (0, 0), (1, 1)],
    );
  }
  return List<List<(double, double)>>.unmodifiable(result);
}

FontMetrics _fontMetrics({
  required int unitsPerEm,
  required BinaryReader hhea,
  required BinaryReader? os2,
}) {
  var ascender = hhea.int16(4);
  var descender = hhea.int16(6);

  // Skia honors OS/2.fsSelection USE_TYPO_METRICS when choosing the font's
  // vertical metrics. Matching that choice keeps the outline baseline aligned
  // with Flutter's native text renderer at the morph endpoints.
  if (os2 != null && os2.length >= 72) {
    final selection = os2.uint16(62);
    if (selection & _useTypoMetrics != 0) {
      final typoAscender = os2.int16(68);
      final typoDescender = os2.int16(70);
      if (typoAscender > typoDescender) {
        ascender = typoAscender;
        descender = typoDescender;
      }
    }
  }

  return FontMetrics(
    unitsPerEm: unitsPerEm,
    ascender: ascender,
    descender: descender,
  );
}

List<_CmapSubtable> _parseCmaps(BinaryReader cmap) {
  cmap.require(0, 4);
  if (cmap.uint16(0) != 0) {
    throw const FontDataException(
      'Unsupported cmap table version',
      tableTag: 'cmap',
    );
  }
  final recordCount = cmap.uint16(2);
  cmap.require(4, 8 * recordCount);
  final candidates = <(int, int, _CmapSubtable)>[];
  final parsedOffsets = <int, _CmapSubtable>{};
  for (var index = 0; index < recordCount; index++) {
    final recordOffset = 4 + 8 * index;
    final platform = cmap.uint16(recordOffset);
    final encoding = cmap.uint16(recordOffset + 2);
    if (!_isUnicodeEncoding(platform, encoding)) continue;
    final subtableOffset = cmap.uint32(recordOffset + 4);
    cmap.require(subtableOffset, 2);
    final format = cmap.uint16(subtableOffset);
    if (format != 4 && format != 12) continue;
    final subtable = parsedOffsets.putIfAbsent(
      subtableOffset,
      () => format == 12
          ? _CmapFormat12.parse(
              cmap.slice(subtableOffset, cmap.length - subtableOffset),
            )
          : _CmapFormat4.parse(
              cmap.slice(subtableOffset, cmap.length - subtableOffset),
            ),
    );
    final formatRank = format == 12 ? 0 : 1;
    final platformRank = platform == 3 ? 0 : 1;
    candidates.add((formatRank, platformRank, subtable));
  }
  candidates.sort((a, b) {
    final formatComparison = a.$1.compareTo(b.$1);
    return formatComparison != 0 ? formatComparison : a.$2.compareTo(b.$2);
  });
  return <_CmapSubtable>[for (final candidate in candidates) candidate.$3];
}

bool _isUnicodeEncoding(int platform, int encoding) =>
    platform == 0 || platform == 3 && (encoding == 1 || encoding == 10);

sealed class _CmapSubtable {
  const _CmapSubtable();
  int? lookup(int codePoint);
}

final class _CmapFormat4 extends _CmapSubtable {
  _CmapFormat4._({
    required this.table,
    required this.endCodes,
    required this.startCodes,
    required this.deltas,
    required this.rangeOffsets,
    required this.rangeOffsetsStart,
  });

  factory _CmapFormat4.parse(BinaryReader input) {
    input.require(0, 8);
    final length = input.uint16(2);
    final table = input.slice(0, length);
    table.require(0, 16);
    final segmentCountX2 = table.uint16(6);
    if (segmentCountX2 == 0 || segmentCountX2.isOdd) {
      throw const FontDataException(
        'Invalid cmap format 4 segment count',
        tableTag: 'cmap',
      );
    }
    final segmentCount = segmentCountX2 ~/ 2;
    final endCodesStart = 14;
    final startCodesStart = endCodesStart + 2 * segmentCount + 2;
    final deltasStart = startCodesStart + 2 * segmentCount;
    final rangeOffsetsStart = deltasStart + 2 * segmentCount;
    table.require(rangeOffsetsStart, 2 * segmentCount);
    if (table.uint16(endCodesStart + 2 * segmentCount) != 0) {
      throw const FontDataException(
        'Invalid cmap format 4 reserved pad',
        tableTag: 'cmap',
      );
    }
    final endCodes = List<int>.generate(
      segmentCount,
      (index) => table.uint16(endCodesStart + 2 * index),
      growable: false,
    );
    final startCodes = List<int>.generate(
      segmentCount,
      (index) => table.uint16(startCodesStart + 2 * index),
      growable: false,
    );
    final deltas = List<int>.generate(
      segmentCount,
      (index) => table.int16(deltasStart + 2 * index),
      growable: false,
    );
    final rangeOffsets = List<int>.generate(
      segmentCount,
      (index) => table.uint16(rangeOffsetsStart + 2 * index),
      growable: false,
    );
    var previousEnd = -1;
    for (var index = 0; index < segmentCount; index++) {
      if (startCodes[index] > endCodes[index] ||
          startCodes[index] <= previousEnd) {
        throw const FontDataException(
          'Overlapping or unsorted cmap format 4 segments',
          tableTag: 'cmap',
        );
      }
      previousEnd = endCodes[index];
      final rangeOffset = rangeOffsets[index];
      if (rangeOffset != 0) {
        final firstGlyph = rangeOffsetsStart + 2 * index + rangeOffset;
        final glyphCount = endCodes[index] - startCodes[index] + 1;
        table.require(firstGlyph, 2 * glyphCount);
      }
    }
    if (endCodes.last != 0xffff) {
      throw const FontDataException(
        'cmap format 4 is missing its sentinel',
        tableTag: 'cmap',
      );
    }
    return _CmapFormat4._(
      table: table,
      endCodes: endCodes,
      startCodes: startCodes,
      deltas: deltas,
      rangeOffsets: rangeOffsets,
      rangeOffsetsStart: rangeOffsetsStart,
    );
  }

  final BinaryReader table;
  final List<int> endCodes;
  final List<int> startCodes;
  final List<int> deltas;
  final List<int> rangeOffsets;
  final int rangeOffsetsStart;

  @override
  int? lookup(int codePoint) {
    if (codePoint > 0xffff) return null;
    var lower = 0;
    var upper = endCodes.length - 1;
    while (lower < upper) {
      final middle = (lower + upper) >> 1;
      if (endCodes[middle] < codePoint) {
        lower = middle + 1;
      } else {
        upper = middle;
      }
    }
    final segment = lower;
    if (codePoint < startCodes[segment] || codePoint > endCodes[segment]) {
      return null;
    }
    final rangeOffset = rangeOffsets[segment];
    if (rangeOffset == 0) {
      final glyph = (codePoint + deltas[segment]) & 0xffff;
      return glyph == 0 ? null : glyph;
    }
    final glyphAddress =
        rangeOffsetsStart +
        2 * segment +
        rangeOffset +
        2 * (codePoint - startCodes[segment]);
    var glyph = table.uint16(glyphAddress);
    if (glyph == 0) return null;
    glyph = (glyph + deltas[segment]) & 0xffff;
    return glyph == 0 ? null : glyph;
  }
}

final class _CmapFormat12 extends _CmapSubtable {
  const _CmapFormat12._(this.groups);

  factory _CmapFormat12.parse(BinaryReader input) {
    input.require(0, 16);
    final length = input.uint32(4);
    final table = input.slice(0, length);
    final groupCount = table.uint32(12);
    if (groupCount > (table.length - 16) ~/ 12) {
      throw const FontDataException(
        'Invalid cmap format 12 group count',
        tableTag: 'cmap',
      );
    }
    final groups = <(int, int, int)>[];
    var previousEnd = -1;
    for (var index = 0; index < groupCount; index++) {
      final offset = 16 + 12 * index;
      final start = table.uint32(offset);
      final end = table.uint32(offset + 4);
      final startGlyph = table.uint32(offset + 8);
      if (start > end || end > 0x10ffff || start <= previousEnd) {
        throw const FontDataException(
          'Overlapping or invalid cmap format 12 groups',
          tableTag: 'cmap',
        );
      }
      if (startGlyph + end - start > 0xffffffff) {
        throw const FontDataException(
          'cmap format 12 glyph range overflows',
          tableTag: 'cmap',
        );
      }
      groups.add((start, end, startGlyph));
      previousEnd = end;
    }
    return _CmapFormat12._(List<(int, int, int)>.unmodifiable(groups));
  }

  final List<(int, int, int)> groups;

  @override
  int? lookup(int codePoint) {
    var lower = 0;
    var upper = groups.length - 1;
    while (lower <= upper) {
      final middle = (lower + upper) >> 1;
      final group = groups[middle];
      if (codePoint < group.$1) {
        upper = middle - 1;
      } else if (codePoint > group.$2) {
        lower = middle + 1;
      } else {
        final glyph = group.$3 + codePoint - group.$1;
        return glyph == 0 ? null : glyph;
      }
    }
    return null;
  }
}
