import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphnext/src/font/binary_reader.dart';
import 'package:morphnext/src/font/open_type_font.dart';

import '../../support/test_font_builder.dart';

void main() {
  test('binary reader decodes signed and unsigned big-endian values', () {
    final reader = BinaryReader(
      Uint8List.fromList(<int>[0xff, 0xfe, 0x12, 0x34]),
    );
    expect(reader.uint8(0), 255);
    expect(reader.int8(0), -1);
    expect(reader.uint16(2), 0x1234);
    expect(reader.int16(0), -2);
    expect(reader.slice(1, 2).uint16(0), 0xfe12);
  });

  test('format 4 maps BMP code points', () {
    final font = OpenTypeFont.parse(
      TestFontBuilder.sfntWithCmaps(
        format4: const <int, int>{0xe001: 3, 0xe010: 4},
      ),
    );
    expect(font.glyphIndexForCodePoint(0xe001), 3);
    expect(font.glyphIndexForCodePoint(0xe010), 4);
    expect(font.glyphIndexForCodePoint(0xe999), isNull);
  });

  test('format 12 maps supplementary code points and is preferred', () {
    final font = OpenTypeFont.parse(
      TestFontBuilder.sfntWithCmaps(
        format4: const <int, int>{0xe001: 1},
        format12: const <int, int>{0xe001: 2, 0x1f680: 4},
      ),
    );
    expect(font.glyphIndexForCodePoint(0xe001), 2);
    expect(font.glyphIndexForCodePoint(0x1f680), 4);
    expect(font.glyphIndexForCodePoint(0x110000), isNull);
  });

  test('reads metrics and repeated final horizontal advance', () {
    final font = OpenTypeFont.parse(
      TestFontBuilder.sfntWithCmaps(format4: const <int, int>{0xe001: 3}),
    );
    expect(font.metrics.unitsPerEm, 1000);
    expect(font.metrics.ascender, 800);
    expect(font.metrics.descender, -200);
    expect(font.advanceWidth(3), 1000);
    expect(font.outlineFormat, OutlineFormat.trueType);
  });

  test('uses OS/2 typo metrics when USE_TYPO_METRICS is set', () {
    final font = OpenTypeFont.parse(
      TestFontBuilder.sfntWithCmaps(
        format4: const <int, int>{0xe001: 3},
        useTypoMetrics: true,
        typoAscender: 448,
        typoDescender: -64,
      ),
    );

    expect(font.metrics.ascender, 448);
    expect(font.metrics.descender, -64);
  });

  test('keeps hhea metrics when USE_TYPO_METRICS is not set', () {
    final font = OpenTypeFont.parse(
      TestFontBuilder.sfntWithCmaps(
        format4: const <int, int>{0xe001: 3},
        typoAscender: 448,
        typoDescender: -64,
      ),
    );

    expect(font.metrics.ascender, 800);
    expect(font.metrics.descender, -200);
  });

  test('invalid offsets fail as FontDataException, not RangeError', () {
    final bytes = TestFontBuilder.sfntWithCmaps(
      format4: const <int, int>{0xe001: 1},
    );
    bytes[20] = 0xff;
    expect(() => OpenTypeFont.parse(bytes), throwsA(isA<FontDataException>()));
  });

  test('bounded reads fail as FontDataException', () {
    final reader = BinaryReader(Uint8List.fromList(<int>[1, 2]));
    expect(() => reader.uint32(0), throwsA(isA<FontDataException>()));
    expect(() => reader.slice(-1, 1), throwsA(isA<FontDataException>()));
  });

  test('TTC, CFF2, and excessive table counts are typed failures', () {
    for (final bytes in <Uint8List>[
      TestFontBuilder.ttcHeader(),
      TestFontBuilder.cff2Sfnt(),
      TestFontBuilder.excessiveTableCount(),
    ]) {
      expect(
        () => OpenTypeFont.parse(bytes),
        throwsA(isA<FontDataException>()),
      );
    }
  });
}
