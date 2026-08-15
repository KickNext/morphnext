import 'dart:math' as math;
import 'dart:typed_data';

enum TrueTypeFault {
  decreasingEndpoints,
  pointOverflow,
  truncatedFlagRun,
  excessiveContours,
  outOfRangeComponent,
  excessiveComponents,
  excessiveDepth,
  missingLoca,
  decreasingLoca,
}

enum CffFault {
  majorVersion,
  badIndexOffset,
  multipleTopDicts,
  badDictReal,
  missingCharStrings,
  invalidFdSelect,
}

final class TestFontBuilder {
  static const quadraticCodePoint = 0xe001;
  static const compositeCodePoint = 0xe002;
  static const nestedCompositeCodePoint = 0xe003;
  static const attachedCompositeCodePoint = 0xe004;
  static const compressedCodePoint = 0xe005;
  static const emptyCodePoint = 0xe006;
  static const byteCompositeCodePoint = 0xe007;
  static const xyScaleCodePoint = 0xe008;
  static const matrixCodePoint = 0xe009;
  static const instructedCompositeCodePoint = 0xe00a;
  static const scaledOffsetCodePoint = 0xe00b;
  static const metricsCompositeCodePoint = 0xe00c;
  static const squareWithHoleCodePoint = 0xe00d;
  static const chevronCodePoint = 0xe00e;
  static const rotatedChevronCodePoint = 0xe00f;
  static const diamondWithHoleCodePoint = 0xe010;
  static const cffCodePoint = 0xe101;
  static const cffAlternateCodePoint = 0xe102;

  static Uint8List trueType({
    bool compositeCycle = false,
    bool truncatedCoordinates = false,
    bool longLoca = false,
    bool includeIcons = true,
    int? quadraticAdvanceWidth,
    Map<int, int> additionalMappings = const <int, int>{},
    Map<String, Uint8List> extraTables = const <String, Uint8List>{},
  }) {
    if (!includeIcons) {
      return sfntWithCmaps(format4: const <int, int>{0xe100: 1});
    }
    var quadratic = _simpleGlyph(<List<(int, int, bool)>>[
      <(int, int, bool)>[
        (0, 0, true),
        (100, 200, false),
        (200, 200, false),
        (300, 0, true),
      ],
    ]);
    if (truncatedCoordinates) {
      quadratic = Uint8List.sublistView(quadratic, 0, quadratic.length - 2);
    }
    final square = _simpleGlyph(<List<(int, int, bool)>>[
      <(int, int, bool)>[
        (0, 0, true),
        (1000, 0, true),
        (1000, 1000, true),
        (0, 1000, true),
      ],
    ]);
    final composite = _compositeGlyph(
      glyphId: compositeCycle ? 3 : 2,
      translateX: 100,
      translateY: 200,
      scale: 0.5,
    );
    final nested = _compositeGlyph(glyphId: 3, translateX: 10, translateY: 20);
    final attached = _attachedCompositeGlyph(baseGlyphId: 2);
    final compressed = _compressedSimpleGlyph();
    final byteComposite = _compositeGlyph(
      glyphId: 2,
      translateX: 10,
      translateY: -20,
      words: false,
    );
    final xyScale = _compositeGlyph(
      glyphId: 2,
      translateX: 0,
      translateY: 0,
      scaleX: 0.5,
      scaleY: 0.25,
    );
    final matrix = _compositeGlyph(
      glyphId: 2,
      translateX: 0,
      translateY: 0,
      matrix: const (0, -1, 1, 0),
    );
    final instructed = _compositeGlyph(
      glyphId: 2,
      translateX: 0,
      translateY: 0,
      instructions: const <int>[0xaa, 0xbb],
    );
    final scaledOffset = _compositeGlyph(
      glyphId: 2,
      translateX: 101,
      translateY: 0,
      scale: 0.5,
      scaledOffset: true,
      roundOffset: true,
    );
    final metricsComposite = _compositeGlyph(
      glyphId: 2,
      translateX: 0,
      translateY: 0,
      useMyMetrics: true,
    );
    final squareWithHole = _simpleGlyph(<List<(int, int, bool)>>[
      const <(int, int, bool)>[
        (100, 100, true),
        (900, 100, true),
        (900, 900, true),
        (100, 900, true),
      ],
      const <(int, int, bool)>[
        (300, 300, true),
        (300, 700, true),
        (700, 700, true),
        (700, 300, true),
      ],
    ]);
    final chevron = _simpleGlyph(<List<(int, int, bool)>>[
      const <(int, int, bool)>[
        (100, 250, true),
        (500, 650, true),
        (900, 250, true),
        (750, 100, true),
        (500, 350, true),
        (250, 100, true),
      ],
    ]);
    final rotatedChevron = _simpleGlyph(<List<(int, int, bool)>>[
      const <(int, int, bool)>[
        (750, 100, true),
        (350, 500, true),
        (750, 900, true),
        (900, 750, true),
        (650, 500, true),
        (900, 250, true),
      ],
    ]);
    final diamondWithHole = _simpleGlyph(<List<(int, int, bool)>>[
      const <(int, int, bool)>[
        (500, 76, true),
        (924, 500, true),
        (500, 924, true),
        (76, 500, true),
      ],
      const <(int, int, bool)>[
        (500, 288, true),
        (288, 500, true),
        (500, 712, true),
        (712, 500, true),
      ],
    ]);
    final glyphs = <Uint8List>[
      Uint8List(0),
      quadratic,
      square,
      composite,
      nested,
      attached,
      compressed,
      Uint8List(0),
      byteComposite,
      xyScale,
      matrix,
      instructed,
      scaledOffset,
      metricsComposite,
      squareWithHole,
      chevron,
      rotatedChevron,
      diamondWithHole,
    ];
    return _trueTypeFromGlyphs(
      glyphs,
      <int, int>{
        quadraticCodePoint: 1,
        compositeCodePoint: 3,
        nestedCompositeCodePoint: 4,
        attachedCompositeCodePoint: 5,
        compressedCodePoint: 6,
        emptyCodePoint: 7,
        byteCompositeCodePoint: 8,
        xyScaleCodePoint: 9,
        matrixCodePoint: 10,
        instructedCompositeCodePoint: 11,
        scaledOffsetCodePoint: 12,
        metricsCompositeCodePoint: 13,
        squareWithHoleCodePoint: 14,
        chevronCodePoint: 15,
        rotatedChevronCodePoint: 16,
        diamondWithHoleCodePoint: 17,
        ...additionalMappings,
      },
      advances: <int>[
        for (var glyph = 0; glyph < glyphs.length; glyph++)
          if (glyph == 1 && quadraticAdvanceWidth != null)
            quadraticAdvanceWidth
          else if (glyph == 2)
            800
          else
            1000,
      ],
      longLoca: longLoca,
      extraTables: extraTables,
    );
  }

  static Uint8List variableTrueType() => trueType(
    extraTables: <String, Uint8List>{
      'fvar': _testFvar(),
      'gvar': _testGvar(
        glyphCount: 18,
        variedGlyphId: 1,
        xDeltas: const <int>[10, 20, 30, 40, 0, 10, 0, 0],
      ),
    },
  );

  static Uint8List variableCompositeTrueType() => trueType(
    extraTables: <String, Uint8List>{
      'fvar': _testFvar(),
      'gvar': _testGvar(
        glyphCount: 18,
        variedGlyphId: 3,
        xDeltas: const <int>[20, 0, 0, 0, 0],
      ),
    },
  );

  static Uint8List malformedTrueType(TrueTypeFault fault) {
    if (fault == TrueTypeFault.missingLoca) {
      final tables = _baseTables(
        numGlyphs: 2,
        cmap: _cmap(
          format4: const <int, int>{quadraticCodePoint: 1},
          format12: const <int, int>{},
        ),
      )..['glyf'] = Uint8List(0);
      return _sfnt(tables, scaler: 0x00010000);
    }
    if (fault == TrueTypeFault.decreasingLoca) {
      final loca = Uint8List(6);
      final data = ByteData.sublistView(loca);
      data.setUint16(2, 5);
      data.setUint16(4, 4);
      final tables = _baseTables(
        numGlyphs: 2,
        cmap: _cmap(
          format4: const <int, int>{quadraticCodePoint: 1},
          format12: const <int, int>{},
        ),
      )..addAll(<String, Uint8List>{'loca': loca, 'glyf': Uint8List(10)});
      return _sfnt(tables, scaler: 0x00010000);
    }
    if (fault == TrueTypeFault.excessiveDepth) {
      final glyphs = <Uint8List>[Uint8List(0)];
      for (var glyphId = 1; glyphId <= 17; glyphId++) {
        glyphs.add(
          _compositeGlyph(
            glyphId: glyphId == 17 ? 0 : glyphId + 1,
            translateX: 0,
            translateY: 0,
          ),
        );
      }
      return _trueTypeFromGlyphs(glyphs, const <int, int>{
        quadraticCodePoint: 1,
      });
    }

    final glyph = switch (fault) {
      TrueTypeFault.decreasingEndpoints => _simpleHeader(
        contourCount: 2,
        endPoints: const <int>[1, 0],
      ),
      TrueTypeFault.pointOverflow => _simpleHeader(
        contourCount: 1,
        endPoints: const <int>[0xffff],
      ),
      TrueTypeFault.truncatedFlagRun => _simpleHeader(
        contourCount: 1,
        endPoints: const <int>[2],
        tail: const <int>[0, 0, 0x09],
      ),
      TrueTypeFault.excessiveContours => _simpleHeader(contourCount: 1025),
      TrueTypeFault.outOfRangeComponent => _compositeGlyph(
        glyphId: 2,
        translateX: 0,
        translateY: 0,
      ),
      TrueTypeFault.excessiveComponents => _manyComponentGlyph(257),
      TrueTypeFault.excessiveDepth ||
      TrueTypeFault.missingLoca ||
      TrueTypeFault.decreasingLoca => throw StateError('Handled above'),
    };
    return _trueTypeFromGlyphs(
      <Uint8List>[Uint8List(0), glyph],
      const <int, int>{quadraticCodePoint: 1},
    );
  }

  static Uint8List _trueTypeFromGlyphs(
    List<Uint8List> glyphs,
    Map<int, int> mappings, {
    List<int>? advances,
    bool longLoca = false,
    Map<String, Uint8List> extraTables = const <String, Uint8List>{},
  }) {
    final glyf = BytesBuilder(copy: false);
    final offsets = <int>[0];
    for (final glyph in glyphs) {
      glyf.add(glyph);
      if (glyph.length.isOdd) glyf.addByte(0);
      offsets.add(glyf.length);
    }
    final entrySize = longLoca ? 4 : 2;
    final loca = Uint8List(entrySize * offsets.length);
    final locaData = ByteData.sublistView(loca);
    for (var index = 0; index < offsets.length; index++) {
      if (longLoca) {
        locaData.setUint32(4 * index, offsets[index]);
      } else {
        locaData.setUint16(2 * index, offsets[index] ~/ 2);
      }
    }
    final tables =
        _baseTables(
          numGlyphs: glyphs.length,
          cmap: _cmap(format4: mappings, format12: const <int, int>{}),
          advances: advances,
          indexToLocFormat: longLoca ? 1 : 0,
        )..addAll(<String, Uint8List>{
          'loca': loca,
          'glyf': glyf.takeBytes(),
          ...extraTables,
        });
    return _sfnt(tables, scaler: 0x00010000);
  }

  static Uint8List _testFvar() {
    final bytes = Uint8List(36);
    final data = ByteData.sublistView(bytes);
    data.setUint16(0, 1);
    data.setUint16(4, 16);
    data.setUint16(6, 2);
    data.setUint16(8, 1);
    data.setUint16(10, 20);
    data.setUint16(12, 0);
    data.setUint16(14, 4);
    bytes.setRange(16, 20, 'wght'.codeUnits);
    data.setInt32(20, 100 * 65536);
    data.setInt32(24, 400 * 65536);
    data.setInt32(28, 900 * 65536);
    return bytes;
  }

  static Uint8List _testGvar({
    required int glyphCount,
    required int variedGlyphId,
    required List<int> xDeltas,
  }) {
    final dataArrayOffset = 20 + 2 * (glyphCount + 1);
    final tupleDataLength = 3 + xDeltas.length;
    final unpaddedGlyphDataLength = 10 + tupleDataLength;
    final glyphDataLength = unpaddedGlyphDataLength.isEven
        ? unpaddedGlyphDataLength
        : unpaddedGlyphDataLength + 1;
    final bytes = Uint8List(dataArrayOffset + glyphDataLength);
    final data = ByteData.sublistView(bytes);
    data.setUint16(0, 1);
    data.setUint16(4, 1);
    data.setUint16(12, glyphCount);
    data.setUint32(16, dataArrayOffset);
    for (var glyph = 0; glyph <= glyphCount; glyph++) {
      final offset = glyph <= variedGlyphId ? 0 : glyphDataLength;
      data.setUint16(20 + 2 * glyph, offset ~/ 2);
    }
    var cursor = dataArrayOffset;
    data.setUint16(cursor, 1);
    data.setUint16(cursor + 2, 10);
    data.setUint16(cursor + 4, tupleDataLength);
    data.setUint16(cursor + 6, 0xa000);
    data.setInt16(cursor + 8, 0x4000);
    cursor += 10;
    bytes[cursor++] = 0;
    bytes[cursor++] = xDeltas.length - 1;
    for (final delta in xDeltas) {
      bytes[cursor++] = delta & 0xff;
    }
    bytes[cursor] = 0x80 | (xDeltas.length - 1);
    return bytes;
  }

  static Uint8List sfntWithCmaps({
    Map<int, int> format4 = const <int, int>{},
    Map<int, int> format12 = const <int, int>{},
    bool useTypoMetrics = false,
    int typoAscender = 800,
    int typoDescender = -200,
  }) {
    final allMappings = <int, int>{...format4, ...format12};
    final numGlyphs = math.max(
      1,
      allMappings.values.fold<int>(0, math.max) + 1,
    );
    final tables =
        _baseTables(
          numGlyphs: numGlyphs,
          cmap: _cmap(format4: format4, format12: format12),
          useTypoMetrics: useTypoMetrics,
          typoAscender: typoAscender,
          typoDescender: typoDescender,
        )..addAll(<String, Uint8List>{
          'loca': Uint8List(2 * (numGlyphs + 1)),
          'glyf': Uint8List(0),
        });
    return _sfnt(tables, scaler: 0x00010000);
  }

  static Uint8List cff1({
    bool useSubroutines = false,
    bool recursiveSubroutine = false,
  }) {
    late final Uint8List glyph;
    var localSubroutines = const <Uint8List>[];
    var globalSubroutines = const <Uint8List>[];
    if (useSubroutines || recursiveSubroutine) {
      glyph = _type2Program(<Object>[
        const <num>[100, 100],
        21,
        const <num>[-107],
        10,
        if (!recursiveSubroutine) ...<Object>[
          const <num>[-107],
          29,
        ],
        14,
      ]);
      localSubroutines = <Uint8List>[
        _type2Program(
          recursiveSubroutine
              ? const <Object>[
                  <num>[-107],
                  10,
                  11,
                ]
              : const <Object>[
                  <num>[800, 0],
                  5,
                  <num>[0, 800],
                  5,
                  11,
                ],
        ),
      ];
      if (!recursiveSubroutine) {
        globalSubroutines = <Uint8List>[
          _type2Program(const <Object>[
            <num>[-800, 0],
            5,
            <num>[0, -800],
            5,
            11,
          ]),
        ];
      }
    } else {
      glyph = _type2Program(const <Object>[
        <num>[100, 100],
        21,
        <num>[800, 0, 0, 800, -800, 0, 0, -800],
        5,
        <num>[200, 200],
        21,
        <num>[50, 50, 50, 50, -50, -50, -50],
        (12, 34),
        14,
      ]);
    }
    final cff = _cff1Table(
      <Uint8List>[
        Uint8List.fromList(const <int>[14]),
        glyph,
      ],
      localSubroutines: localSubroutines,
      globalSubroutines: globalSubroutines,
    );
    final tables = _baseTables(
      numGlyphs: 2,
      cff: true,
      cmap: _cmap(
        format4: const <int, int>{cffCodePoint: 1},
        format12: const <int, int>{},
      ),
    )..['CFF '] = cff;
    return _sfnt(tables, scaler: 0x4f54544f);
  }

  static Uint8List cff1WithProgram(
    List<Object> program, {
    List<List<Object>> localSubroutines = const <List<Object>>[],
    List<List<Object>> globalSubroutines = const <List<Object>>[],
  }) {
    final cff = _cff1Table(
      <Uint8List>[
        Uint8List.fromList(const <int>[14]),
        _type2Program(program),
      ],
      localSubroutines: <Uint8List>[
        for (final subroutine in localSubroutines) _type2Program(subroutine),
      ],
      globalSubroutines: <Uint8List>[
        for (final subroutine in globalSubroutines) _type2Program(subroutine),
      ],
    );
    final tables = _baseTables(
      numGlyphs: 2,
      cff: true,
      cmap: _cmap(
        format4: const <int, int>{cffCodePoint: 1},
        format12: const <int, int>{},
      ),
    )..['CFF '] = cff;
    return _sfnt(tables, scaler: 0x4f54544f);
  }

  static Uint8List cff1Cid({required int fdSelectFormat}) {
    final cff = _cff1CidTable(fdSelectFormat);
    final tables = _baseTables(
      numGlyphs: 3,
      cff: true,
      cmap: _cmap(
        format4: const <int, int>{cffCodePoint: 1, cffAlternateCodePoint: 2},
        format12: const <int, int>{},
      ),
    )..['CFF '] = cff;
    return _sfnt(tables, scaler: 0x4f54544f);
  }

  static Uint8List cff1WithSubroutineCount(int count) {
    final bias = count < 1240
        ? 107
        : count < 33900
        ? 1131
        : 32768;
    return cff1WithProgram(
      <Object>[
        const <num>[0, 0],
        21,
        <num>[-bias],
        10,
        14,
      ],
      localSubroutines: <List<Object>>[
        const <Object>[
          <num>[100, 0],
          5,
          11,
        ],
        for (var index = 1; index < count; index++) const <Object>[11],
      ],
    );
  }

  static Uint8List cff1WithDictEncodings() => _cffSfnt(
    _cff1Table(
      <Uint8List>[
        Uint8List.fromList(const <int>[14]),
        _type2Program(const <Object>[
          <num>[0, 0],
          21,
          <num>[10, 0],
          5,
          14,
        ]),
      ],
      topDictPrefix: const <int>[
        139,
        0,
        247,
        0,
        1,
        251,
        0,
        2,
        28,
        0x07,
        0xd0,
        3,
        30,
        0x0a,
        0x5f,
        4,
      ],
    ),
    numGlyphs: 2,
    mappings: const <int, int>{cffCodePoint: 1},
  );

  static Uint8List malformedCff1(CffFault fault) {
    if (fault == CffFault.invalidFdSelect) {
      return _cffSfnt(
        _cff1CidTable(2, allowUnsupportedFormat: true),
        numGlyphs: 3,
        mappings: const <int, int>{cffCodePoint: 1},
      );
    }
    late final Uint8List cff;
    if (fault == CffFault.multipleTopDicts ||
        fault == CffFault.badDictReal ||
        fault == CffFault.missingCharStrings) {
      final topDicts = switch (fault) {
        CffFault.multipleTopDicts => <Uint8List>[Uint8List(0), Uint8List(0)],
        CffFault.badDictReal => <Uint8List>[
          Uint8List.fromList(const <int>[30, 0xdf, 17]),
        ],
        CffFault.missingCharStrings => <Uint8List>[Uint8List(0)],
        _ => throw StateError('Handled separately'),
      };
      cff =
          (BytesBuilder(copy: false)
                ..add(const <int>[1, 0, 4, 4])
                ..add(
                  _cffIndex(<Uint8List>[
                    Uint8List.fromList('MorphnextBad'.codeUnits),
                  ]),
                )
                ..add(_cffIndex(topDicts))
                ..add(_cffIndex(const <Uint8List>[]))
                ..add(_cffIndex(const <Uint8List>[])))
              .takeBytes();
    } else {
      cff = _cff1Table(<Uint8List>[
        Uint8List.fromList(const <int>[14]),
        Uint8List.fromList(const <int>[14]),
      ]);
      if (fault == CffFault.majorVersion) {
        cff[0] = 2;
      } else if (fault == CffFault.badIndexOffset) {
        cff[7] = 0;
      }
    }
    return _cffSfnt(
      cff,
      numGlyphs: 2,
      mappings: const <int, int>{cffCodePoint: 1},
    );
  }

  static Uint8List ttcHeader() {
    final bytes = Uint8List(12);
    final data = ByteData.sublistView(bytes);
    data.setUint32(0, 0x74746366);
    data.setUint32(4, 0x00010000);
    data.setUint32(8, 1);
    return bytes;
  }

  static Uint8List cff2Sfnt() {
    final tables = _baseTables(
      numGlyphs: 2,
      cff: true,
      cmap: _cmap(
        format4: const <int, int>{quadraticCodePoint: 1},
        format12: const <int, int>{},
      ),
    )..['CFF2'] = Uint8List.fromList(<int>[2, 0, 5, 0, 0]);
    return _sfnt(tables, scaler: 0x4f54544f);
  }

  static Uint8List excessiveTableCount() {
    final bytes = Uint8List(12);
    final data = ByteData.sublistView(bytes);
    data.setUint32(0, 0x00010000);
    data.setUint16(4, 129);
    return bytes;
  }

  static Map<String, Uint8List> _baseTables({
    required int numGlyphs,
    required Uint8List cmap,
    List<int>? advances,
    int indexToLocFormat = 0,
    bool cff = false,
    bool useTypoMetrics = false,
    int typoAscender = 800,
    int typoDescender = -200,
  }) => <String, Uint8List>{
    'head': _head(indexToLocFormat),
    'hhea': _hhea(numGlyphs),
    'maxp': _maxp(numGlyphs, cff: cff),
    'hmtx': _hmtx(numGlyphs, advances),
    'cmap': cmap,
    'name': _name(),
    'OS/2': _os2(
      useTypoMetrics: useTypoMetrics,
      typoAscender: typoAscender,
      typoDescender: typoDescender,
    ),
    'post': _post(),
  };

  static Uint8List _head(int indexToLocFormat) {
    final bytes = Uint8List(54);
    final data = ByteData.sublistView(bytes);
    data.setUint32(0, 0x00010000);
    data.setUint32(4, 0x00010000);
    data.setUint32(12, 0x5f0f3cf5);
    data.setUint16(18, 1000);
    data.setInt16(36, 0);
    data.setInt16(38, -200);
    data.setInt16(40, 1000);
    data.setInt16(42, 800);
    data.setUint16(46, 8);
    data.setInt16(48, 2);
    data.setInt16(50, indexToLocFormat);
    return bytes;
  }

  static Uint8List _hhea(int numGlyphs) {
    final bytes = Uint8List(36);
    final data = ByteData.sublistView(bytes);
    data.setUint32(0, 0x00010000);
    data.setInt16(4, 800);
    data.setInt16(6, -200);
    data.setUint16(10, 1000);
    data.setInt16(12, 0);
    data.setInt16(14, 0);
    data.setInt16(16, 1000);
    data.setInt16(18, 1);
    data.setInt16(20, 0);
    data.setInt16(22, 0);
    data.setInt16(32, 0);
    data.setUint16(34, numGlyphs);
    return bytes;
  }

  static Uint8List _maxp(int numGlyphs, {required bool cff}) {
    final bytes = Uint8List(cff ? 6 : 32);
    final data = ByteData.sublistView(bytes);
    data.setUint32(0, cff ? 0x00005000 : 0x00010000);
    data.setUint16(4, numGlyphs);
    if (!cff) {
      data.setUint16(6, 64);
      data.setUint16(8, 8);
      data.setUint16(10, 256);
      data.setUint16(12, 32);
      data.setUint16(14, 2);
      data.setUint16(26, 256);
      data.setUint16(28, 256);
      data.setUint16(30, 16);
    }
    return bytes;
  }

  static Uint8List _name() {
    const names = <int, String>{
      1: 'Morphnext Test',
      2: 'Regular',
      4: 'Morphnext Test Regular',
      6: 'MorphnextTest-Regular',
    };
    final encoded = <int, List<int>>{
      for (final entry in names.entries)
        entry.key: <int>[
          for (final unit in entry.value.codeUnits) ...<int>[
            unit >> 8,
            unit & 0xff,
          ],
        ],
    };
    final stringOffset = 6 + 12 * names.length;
    final stringLength = encoded.values.fold<int>(
      0,
      (total, value) => total + value.length,
    );
    final bytes = Uint8List(stringOffset + stringLength);
    final data = ByteData.sublistView(bytes);
    data.setUint16(2, names.length);
    data.setUint16(4, stringOffset);
    var valueOffset = 0;
    var record = 6;
    for (final entry in encoded.entries) {
      data.setUint16(record, 3);
      data.setUint16(record + 2, 1);
      data.setUint16(record + 4, 0x0409);
      data.setUint16(record + 6, entry.key);
      data.setUint16(record + 8, entry.value.length);
      data.setUint16(record + 10, valueOffset);
      bytes.setRange(
        stringOffset + valueOffset,
        stringOffset + valueOffset + entry.value.length,
        entry.value,
      );
      record += 12;
      valueOffset += entry.value.length;
    }
    return bytes;
  }

  static Uint8List _os2({
    bool useTypoMetrics = false,
    int typoAscender = 800,
    int typoDescender = -200,
  }) {
    final bytes = Uint8List(96);
    final data = ByteData.sublistView(bytes);
    data.setUint16(0, 4);
    data.setInt16(2, 500);
    data.setUint16(4, 400);
    data.setUint16(6, 5);
    data.setInt16(10, 650);
    data.setInt16(12, 700);
    data.setInt16(16, 140);
    data.setInt16(18, 650);
    data.setInt16(20, 700);
    data.setInt16(24, 480);
    data.setInt16(26, 50);
    data.setInt16(28, 250);
    data.setUint32(46, 0x10000000);
    bytes.setRange(58, 62, 'MORF'.codeUnits);
    data.setUint16(62, 0x0040 | (useTypoMetrics ? 0x0080 : 0));
    data.setUint16(64, 0xe000);
    data.setUint16(66, 0xe1ff);
    data.setInt16(68, typoAscender);
    data.setInt16(70, typoDescender);
    data.setUint16(74, 800);
    data.setUint16(76, 200);
    data.setInt16(88, 700);
    data.setUint16(92, 32);
    data.setUint16(94, 1);
    return bytes;
  }

  static Uint8List _post() {
    final bytes = Uint8List(32);
    final data = ByteData.sublistView(bytes);
    data.setUint32(0, 0x00030000);
    data.setInt16(8, -75);
    data.setInt16(10, 50);
    return bytes;
  }

  static Uint8List _hmtx(int numGlyphs, List<int>? advances) {
    if (advances != null && advances.length != numGlyphs) {
      throw ArgumentError.value(advances, 'advances');
    }
    final bytes = Uint8List(4 * numGlyphs);
    final data = ByteData.sublistView(bytes);
    for (var glyph = 0; glyph < numGlyphs; glyph++) {
      data.setUint16(4 * glyph, advances?[glyph] ?? 1000);
      data.setInt16(4 * glyph + 2, 0);
    }
    return bytes;
  }

  static Uint8List _simpleGlyph(List<List<(int, int, bool)>> contours) {
    final points = contours
        .expand((contour) => contour)
        .toList(growable: false);
    final bytes = BytesBuilder(copy: false);
    final header = Uint8List(10 + 2 * contours.length + 2);
    final headerData = ByteData.sublistView(header);
    headerData.setInt16(0, contours.length);
    headerData.setInt16(2, points.map((point) => point.$1).reduce(math.min));
    headerData.setInt16(4, points.map((point) => point.$2).reduce(math.min));
    headerData.setInt16(6, points.map((point) => point.$1).reduce(math.max));
    headerData.setInt16(8, points.map((point) => point.$2).reduce(math.max));
    var endPoint = -1;
    for (var i = 0; i < contours.length; i++) {
      endPoint += contours[i].length;
      headerData.setUint16(10 + 2 * i, endPoint);
    }
    headerData.setUint16(10 + 2 * contours.length, 0);
    bytes.add(header);
    bytes.add(<int>[
      for (final point in points)
        if (point.$3) 0x01 else 0x00,
    ]);

    var previousX = 0;
    for (final point in points) {
      final delta = point.$1 - previousX;
      bytes.add(<int>[(delta >> 8) & 0xff, delta & 0xff]);
      previousX = point.$1;
    }
    var previousY = 0;
    for (final point in points) {
      final delta = point.$2 - previousY;
      bytes.add(<int>[(delta >> 8) & 0xff, delta & 0xff]);
      previousY = point.$2;
    }
    return bytes.takeBytes();
  }

  static Uint8List _compressedSimpleGlyph() {
    final header = Uint8List(14);
    final data = ByteData.sublistView(header);
    data.setInt16(0, 1);
    data.setInt16(2, 0);
    data.setInt16(4, -400);
    data.setInt16(6, 400);
    data.setInt16(8, 30);
    data.setUint16(10, 5);
    data.setUint16(12, 0);
    return Uint8List.fromList(<int>[
      ...header,
      0x31,
      0x37,
      0x07,
      0x39,
      1,
      0x01,
      20,
      10,
      0x01,
      0x86,
      30,
      10,
      0xfe,
      0x5c,
    ]);
  }

  static Uint8List _simpleHeader({
    required int contourCount,
    List<int> endPoints = const <int>[],
    List<int> tail = const <int>[],
  }) {
    final bytes = Uint8List(10 + 2 * endPoints.length + tail.length);
    final data = ByteData.sublistView(bytes);
    data.setInt16(0, contourCount);
    for (var index = 0; index < endPoints.length; index++) {
      data.setUint16(10 + 2 * index, endPoints[index]);
    }
    bytes.setRange(10 + 2 * endPoints.length, bytes.length, tail);
    return bytes;
  }

  static Uint8List _manyComponentGlyph(int count) {
    final bytes = Uint8List(10 + 6 * count);
    final data = ByteData.sublistView(bytes)..setInt16(0, -1);
    for (var index = 0; index < count; index++) {
      final offset = 10 + 6 * index;
      data.setUint16(offset, 0x0002 | (index + 1 < count ? 0x0020 : 0));
      data.setUint16(offset + 2, 0);
    }
    return bytes;
  }

  static Uint8List _compositeGlyph({
    required int glyphId,
    required int translateX,
    required int translateY,
    bool words = true,
    double? scale,
    double? scaleX,
    double? scaleY,
    (double, double, double, double)? matrix,
    bool scaledOffset = false,
    bool roundOffset = false,
    bool useMyMetrics = false,
    List<int> instructions = const <int>[],
  }) {
    final transformCount =
        (scale != null ? 1 : 0) +
        (scaleX != null || scaleY != null ? 1 : 0) +
        (matrix != null ? 1 : 0);
    if (transformCount > 1 || (scaleX == null) != (scaleY == null)) {
      throw ArgumentError('Exactly one complete composite transform is valid');
    }
    var flags = 0x0002;
    if (words) flags |= 0x0001;
    if (roundOffset) flags |= 0x0004;
    if (scale != null) flags |= 0x0008;
    if (scaleX != null) flags |= 0x0040;
    if (matrix != null) flags |= 0x0080;
    if (instructions.isNotEmpty) flags |= 0x0100;
    if (useMyMetrics) flags |= 0x0200;
    if (scaledOffset) flags |= 0x0800;

    final transformValues = <double>[
      ?scale,
      if (scaleX != null) ...<double>[scaleX, scaleY!],
      if (matrix != null) ...<double>[
        matrix.$1,
        matrix.$2,
        matrix.$3,
        matrix.$4,
      ],
    ];
    final record = Uint8List(4 + (words ? 4 : 2) + 2 * transformValues.length);
    final recordData = ByteData.sublistView(record);
    recordData.setUint16(0, flags);
    recordData.setUint16(2, glyphId);
    var cursor = 4;
    if (words) {
      recordData.setInt16(cursor, translateX);
      recordData.setInt16(cursor + 2, translateY);
      cursor += 4;
    } else {
      recordData.setInt8(cursor, translateX);
      recordData.setInt8(cursor + 1, translateY);
      cursor += 2;
    }
    for (final value in transformValues) {
      recordData.setInt16(cursor, (value * 16384).round());
      cursor += 2;
    }

    final header = Uint8List(10);
    ByteData.sublistView(header).setInt16(0, -1);
    final output = BytesBuilder(copy: false)
      ..add(header)
      ..add(record);
    if (instructions.isNotEmpty) {
      final length = Uint8List(2);
      ByteData.sublistView(length).setUint16(0, instructions.length);
      output
        ..add(length)
        ..add(instructions);
    }
    return output.takeBytes();
  }

  static Uint8List _attachedCompositeGlyph({required int baseGlyphId}) {
    final bytes = Uint8List(26);
    final data = ByteData.sublistView(bytes);
    data.setInt16(0, -1);
    data.setInt16(2, 0);
    data.setInt16(4, 0);
    data.setInt16(6, 2000);
    data.setInt16(8, 1000);
    data.setUint16(10, 0x0001 | 0x0002 | 0x0020);
    data.setUint16(12, baseGlyphId);
    data.setInt16(14, 0);
    data.setInt16(16, 0);
    data.setUint16(18, 0x0001);
    data.setUint16(20, baseGlyphId);
    data.setUint16(22, 1);
    data.setUint16(24, 0);
    return bytes;
  }

  static Uint8List _cffSfnt(
    Uint8List cff, {
    required int numGlyphs,
    required Map<int, int> mappings,
  }) {
    final tables = _baseTables(
      numGlyphs: numGlyphs,
      cff: true,
      cmap: _cmap(format4: mappings, format12: const <int, int>{}),
    )..['CFF '] = cff;
    return _sfnt(tables, scaler: 0x4f54544f);
  }

  static Uint8List _cff1Table(
    List<Uint8List> charStrings, {
    List<Uint8List> localSubroutines = const <Uint8List>[],
    List<Uint8List> globalSubroutines = const <Uint8List>[],
    List<int> topDictPrefix = const <int>[],
  }) {
    final header = Uint8List.fromList(const <int>[1, 0, 4, 4]);
    final nameIndex = _cffIndex(<Uint8List>[
      Uint8List.fromList('MorphnextTest'.codeUnits),
    ]);
    final stringIndex = _cffIndex(const <Uint8List>[]);
    final globalIndex = _cffIndex(globalSubroutines);
    final charStringsIndex = _cffIndex(charStrings);
    final privateDict = localSubroutines.isEmpty
        ? Uint8List(0)
        : Uint8List.fromList(<int>[..._cffDictLong(6), 19]);
    final localIndex = _cffIndex(localSubroutines);

    Uint8List topDict(int charStringsOffset, int privateOffset) =>
        Uint8List.fromList(<int>[
          ...topDictPrefix,
          ..._cffDictLong(charStringsOffset),
          17,
          ..._cffDictLong(privateDict.length),
          ..._cffDictLong(privateOffset),
          18,
        ]);

    final placeholderTop = _cffIndex(<Uint8List>[topDict(0, 0)]);
    final charStringsOffset =
        header.length +
        nameIndex.length +
        placeholderTop.length +
        stringIndex.length +
        globalIndex.length;
    final privateOffset = charStringsOffset + charStringsIndex.length;
    final topIndex = _cffIndex(<Uint8List>[
      topDict(charStringsOffset, privateOffset),
    ]);
    final output = BytesBuilder(copy: false)
      ..add(header)
      ..add(nameIndex)
      ..add(topIndex)
      ..add(stringIndex)
      ..add(globalIndex)
      ..add(charStringsIndex)
      ..add(privateDict);
    if (localSubroutines.isNotEmpty) output.add(localIndex);
    return output.takeBytes();
  }

  static Uint8List _cff1CidTable(
    int fdSelectFormat, {
    bool allowUnsupportedFormat = false,
  }) {
    final header = Uint8List.fromList(const <int>[1, 0, 4, 4]);
    final nameIndex = _cffIndex(<Uint8List>[
      Uint8List.fromList('MorphnextCID'.codeUnits),
    ]);
    final stringIndex = _cffIndex(const <Uint8List>[]);
    final globalIndex = _cffIndex(const <Uint8List>[]);
    final charStringsIndex = _cffIndex(<Uint8List>[
      Uint8List.fromList(const <int>[14]),
      _type2Program(const <Object>[
        <num>[100, 100],
        21,
        <num>[-107],
        10,
        14,
      ]),
      _type2Program(const <Object>[
        <num>[100, 100],
        21,
        <num>[-107],
        10,
        14,
      ]),
    ]);
    final localIndexes = <Uint8List>[
      _cffIndex(<Uint8List>[
        _type2Program(const <Object>[
          <num>[100, 0],
          5,
          11,
        ]),
      ]),
      _cffIndex(<Uint8List>[
        _type2Program(const <Object>[
          <num>[300, 0],
          5,
          11,
        ]),
      ]),
    ];
    final privateDicts = <Uint8List>[
      for (var index = 0; index < 2; index++)
        Uint8List.fromList(<int>[..._cffDictLong(6), 19]),
    ];
    final fdSelect = switch (fdSelectFormat) {
      0 => Uint8List.fromList(const <int>[0, 0, 0, 1]),
      3 => Uint8List.fromList(const <int>[3, 0, 2, 0, 0, 0, 0, 2, 1, 0, 3]),
      _ when allowUnsupportedFormat => Uint8List.fromList(<int>[
        fdSelectFormat,
      ]),
      _ => throw ArgumentError.value(fdSelectFormat, 'fdSelectFormat'),
    };

    Uint8List topDict(
      int charStringsOffset,
      int fdArrayOffset,
      int fdSelectOffset,
    ) => Uint8List.fromList(<int>[
      ..._cffDictLong(0),
      ..._cffDictLong(1),
      ..._cffDictLong(0),
      12,
      30,
      ..._cffDictLong(charStringsOffset),
      17,
      ..._cffDictLong(fdArrayOffset),
      12,
      36,
      ..._cffDictLong(fdSelectOffset),
      12,
      37,
    ]);

    Uint8List fontDict(int privateOffset) => Uint8List.fromList(<int>[
      ..._cffDictLong(6),
      ..._cffDictLong(privateOffset),
      18,
    ]);

    final placeholderTop = _cffIndex(<Uint8List>[topDict(0, 0, 0)]);
    final placeholderFontDicts = _cffIndex(<Uint8List>[
      fontDict(0),
      fontDict(0),
    ]);
    final charStringsOffset =
        header.length +
        nameIndex.length +
        placeholderTop.length +
        stringIndex.length +
        globalIndex.length;
    final fdArrayOffset = charStringsOffset + charStringsIndex.length;
    final fdSelectOffset = fdArrayOffset + placeholderFontDicts.length;
    final private0Offset = fdSelectOffset + fdSelect.length;
    final private1Offset =
        private0Offset + privateDicts[0].length + localIndexes[0].length;
    final fontDictIndex = _cffIndex(<Uint8List>[
      fontDict(private0Offset),
      fontDict(private1Offset),
    ]);
    final topIndex = _cffIndex(<Uint8List>[
      topDict(charStringsOffset, fdArrayOffset, fdSelectOffset),
    ]);
    return (BytesBuilder(copy: false)
          ..add(header)
          ..add(nameIndex)
          ..add(topIndex)
          ..add(stringIndex)
          ..add(globalIndex)
          ..add(charStringsIndex)
          ..add(fontDictIndex)
          ..add(fdSelect)
          ..add(privateDicts[0])
          ..add(localIndexes[0])
          ..add(privateDicts[1])
          ..add(localIndexes[1]))
        .takeBytes();
  }

  static Uint8List _cffIndex(List<Uint8List> objects) {
    if (objects.isEmpty) return Uint8List(2);
    final offsets = <int>[1];
    for (final object in objects) {
      offsets.add(offsets.last + object.length);
    }
    final offSize = math.max(1, (offsets.last.bitLength + 7) ~/ 8);
    final headerLength = 3 + offSize * offsets.length;
    final bytes = Uint8List(headerLength + offsets.last - 1);
    ByteData.sublistView(bytes).setUint16(0, objects.length);
    bytes[2] = offSize;
    for (var index = 0; index < offsets.length; index++) {
      var value = offsets[index];
      for (var byte = offSize - 1; byte >= 0; byte--) {
        bytes[3 + offSize * index + byte] = value & 0xff;
        value >>= 8;
      }
    }
    var cursor = headerLength;
    for (final object in objects) {
      bytes.setRange(cursor, cursor + object.length, object);
      cursor += object.length;
    }
    return bytes;
  }

  static List<int> _cffDictLong(int value) {
    final bytes = Uint8List(5)..[0] = 29;
    ByteData.sublistView(bytes).setInt32(1, value);
    return bytes;
  }

  static Uint8List _type2Program(List<Object> parts) {
    final bytes = <int>[];
    for (final part in parts) {
      if (part is Uint8List) {
        bytes.addAll(part);
      } else if (part is List<num>) {
        for (final value in part) {
          bytes.addAll(_type2Number(value));
        }
      } else if (part is int) {
        bytes.add(part);
      } else if (part is (int, int)) {
        bytes.addAll(<int>[part.$1, part.$2]);
      } else {
        throw ArgumentError.value(part, 'parts');
      }
    }
    return Uint8List.fromList(bytes);
  }

  static List<int> _type2Number(num value) {
    if (value is double) {
      final bytes = Uint8List(5)..[0] = 255;
      ByteData.sublistView(bytes).setInt32(1, (value * 65536).round());
      return bytes;
    }
    final integer = value as int;
    if (integer >= -107 && integer <= 107) return <int>[integer + 139];
    if (integer >= 108 && integer <= 1131) {
      final adjusted = integer - 108;
      return <int>[247 + (adjusted >> 8), adjusted & 0xff];
    }
    if (integer >= -1131 && integer <= -108) {
      final adjusted = -integer - 108;
      return <int>[251 + (adjusted >> 8), adjusted & 0xff];
    }
    final bytes = Uint8List(3)..[0] = 28;
    ByteData.sublistView(bytes).setInt16(1, integer);
    return bytes;
  }

  static Uint8List _cmap({
    required Map<int, int> format4,
    required Map<int, int> format12,
  }) {
    final subtables = <(int, int, Uint8List)>[
      if (format4.isNotEmpty) (3, 1, _format4(format4)),
      if (format12.isNotEmpty) (3, 10, _format12(format12)),
    ];
    final headerLength = 4 + 8 * subtables.length;
    final totalLength =
        headerLength +
        subtables.fold<int>(0, (sum, item) => sum + item.$3.length);
    final bytes = Uint8List(totalLength);
    final data = ByteData.sublistView(bytes);
    data.setUint16(0, 0);
    data.setUint16(2, subtables.length);
    var offset = headerLength;
    for (var i = 0; i < subtables.length; i++) {
      final (platform, encoding, table) = subtables[i];
      data.setUint16(4 + 8 * i, platform);
      data.setUint16(6 + 8 * i, encoding);
      data.setUint32(8 + 8 * i, offset);
      bytes.setRange(offset, offset + table.length, table);
      offset += table.length;
    }
    return bytes;
  }

  static Uint8List _format4(Map<int, int> mappings) {
    final entries =
        mappings.entries.where((entry) => entry.key <= 0xffff).toList()
          ..sort((a, b) => a.key.compareTo(b.key));
    final segmentCount = entries.length + 1;
    final length = 16 + 8 * segmentCount;
    final bytes = Uint8List(length);
    final data = ByteData.sublistView(bytes);
    data.setUint16(0, 4);
    data.setUint16(2, length);
    data.setUint16(6, 2 * segmentCount);
    final power = _largestPowerOfTwo(segmentCount);
    data.setUint16(8, 2 * power);
    data.setUint16(10, math.log(power) ~/ math.ln2);
    data.setUint16(12, 2 * segmentCount - 2 * power);
    final endOffset = 14;
    final startOffset = endOffset + 2 * segmentCount + 2;
    final deltaOffset = startOffset + 2 * segmentCount;
    final rangeOffset = deltaOffset + 2 * segmentCount;
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      data.setUint16(endOffset + 2 * i, entry.key);
      data.setUint16(startOffset + 2 * i, entry.key);
      data.setUint16(deltaOffset + 2 * i, (entry.value - entry.key) & 0xffff);
      data.setUint16(rangeOffset + 2 * i, 0);
    }
    final sentinel = segmentCount - 1;
    data.setUint16(endOffset + 2 * sentinel, 0xffff);
    data.setUint16(startOffset + 2 * sentinel, 0xffff);
    data.setUint16(deltaOffset + 2 * sentinel, 1);
    return bytes;
  }

  static Uint8List _format12(Map<int, int> mappings) {
    final entries = mappings.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final length = 16 + 12 * entries.length;
    final bytes = Uint8List(length);
    final data = ByteData.sublistView(bytes);
    data.setUint16(0, 12);
    data.setUint32(4, length);
    data.setUint32(12, entries.length);
    for (var i = 0; i < entries.length; i++) {
      data.setUint32(16 + 12 * i, entries[i].key);
      data.setUint32(20 + 12 * i, entries[i].key);
      data.setUint32(24 + 12 * i, entries[i].value);
    }
    return bytes;
  }

  static Uint8List _sfnt(
    Map<String, Uint8List> inputTables, {
    required int scaler,
  }) {
    final tags = inputTables.keys.toList()..sort();
    final directoryLength = 12 + 16 * tags.length;
    final offsets = <String, int>{};
    var totalLength = directoryLength;
    for (final tag in tags) {
      totalLength = (totalLength + 3) & ~3;
      offsets[tag] = totalLength;
      totalLength += inputTables[tag]!.length;
    }
    final bytes = Uint8List((totalLength + 3) & ~3);
    final data = ByteData.sublistView(bytes);
    data.setUint32(0, scaler);
    data.setUint16(4, tags.length);
    final power = _largestPowerOfTwo(tags.length);
    data.setUint16(6, 16 * power);
    data.setUint16(8, math.log(power) ~/ math.ln2);
    data.setUint16(10, 16 * tags.length - 16 * power);
    for (var i = 0; i < tags.length; i++) {
      final tag = tags[i];
      final table = inputTables[tag]!;
      final record = 12 + 16 * i;
      for (var j = 0; j < 4; j++) {
        bytes[record + j] = tag.codeUnitAt(j);
      }
      data.setUint32(record + 4, _checksum(table));
      data.setUint32(record + 8, offsets[tag]!);
      data.setUint32(record + 12, table.length);
      bytes.setRange(offsets[tag]!, offsets[tag]! + table.length, table);
    }
    final checksumAdjustment = (0xb1b0afba - _checksum(bytes)) & 0xffffffff;
    data.setUint32(offsets['head']! + 8, checksumAdjustment);
    return bytes;
  }

  static int _largestPowerOfTwo(int value) {
    var power = 1;
    while (power * 2 <= value) {
      power *= 2;
    }
    return power;
  }

  static int _checksum(Uint8List bytes) {
    var sum = 0;
    for (var offset = 0; offset < bytes.length; offset += 4) {
      var word = 0;
      for (var i = 0; i < 4; i++) {
        word =
            (word << 8) | (offset + i < bytes.length ? bytes[offset + i] : 0);
      }
      sum = (sum + word) & 0xffffffff;
    }
    return sum;
  }
}
