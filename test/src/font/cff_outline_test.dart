import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphnext/src/font/binary_reader.dart';
import 'package:morphnext/src/font/open_type_font.dart';
import 'package:morphnext/src/geometry/shape.dart';

import '../../support/test_font_builder.dart';

void main() {
  test('CFF1 decodes lines, flex curves, and closes contours', () {
    final glyph = OpenTypeFont.parse(
      TestFontBuilder.cff1(),
    ).glyphForCodePoint(TestFontBuilder.cffCodePoint);

    expect(glyph.contours, hasLength(2));
    expect(
      glyph.contours
          .expand((contour) => contour.points)
          .every((value) => value.isFinite),
      isTrue,
    );
    expect(glyph.advanceWidth, 1000);
  });

  test('local and global subroutines apply the Type 2 bias', () {
    final glyph = OpenTypeFont.parse(
      TestFontBuilder.cff1(useSubroutines: true),
    ).glyphForCodePoint(TestFontBuilder.cffCodePoint);

    expect(cubicBounds(glyph.contours), (100, 100, 900, 900));
  });

  test('recursive subroutines fail with a typed exception', () {
    expect(
      () => OpenTypeFont.parse(
        TestFontBuilder.cff1(recursiveSubroutine: true),
      ).glyphForCodePoint(TestFontBuilder.cffCodePoint),
      throwsA(isA<FontDataException>()),
    );
  });

  test('all Type 2 line and curve operators reach exact endpoints', () {
    final cases = <(String, Object, List<num>, (double, double))>[
      ('rlineto', 5, <num>[10, 20, 30, -5], (40, 15)),
      ('hlineto', 6, <num>[10, 20, 30], (40, 20)),
      ('vlineto', 7, <num>[10, 20, 30], (20, 40)),
      ('rrcurveto', 8, <num>[10, 0, 10, 10, 0, 10], (20, 20)),
      ('rcurveline', 24, <num>[10, 0, 10, 10, 0, 10, 5, 6], (25, 26)),
      ('rlinecurve', 25, <num>[5, 6, 10, 0, 10, 10, 0, 10], (25, 26)),
      ('vvcurveto', 26, <num>[5, 10, 20, 30, 40], (25, 80)),
      ('hhcurveto', 27, <num>[5, 10, 20, 30, 40], (70, 35)),
      ('vhcurveto', 30, <num>[10, 20, 30, 40, 50], (60, 90)),
      ('hvcurveto', 31, <num>[10, 20, 30, 40, 50], (80, 70)),
      ('hflex', (12, 34), <num>[10, 20, 5, 30, 40, 50, 60], (210, 0)),
      (
        'flex',
        (12, 35),
        <num>[10, 1, 10, 1, 10, 1, 10, 1, 10, 1, 10, 1, 50],
        (60, 6),
      ),
      ('hflex1', (12, 36), <num>[10, 2, 20, 3, 30, 40, 50, 4, 60], (210, 0)),
      (
        'flex1',
        (12, 37),
        <num>[10, 1, 10, 1, 10, 1, 10, 1, 10, 1, 20],
        (70, 0),
      ),
    ];

    for (final (name, operator, operands, endpoint) in cases) {
      final glyph = glyphFor(<Object>[
        const <num>[0, 0],
        21,
        operands,
        operator,
        14,
      ]);
      expect(explicitEndpoint(glyph.contours.single), endpoint, reason: name);
    }
  });

  test('rmoveto, hmoveto, and vmoveto remove optional widths', () {
    final cases = <(String, int, List<num>, (double, double))>[
      ('rmoveto', 21, <num>[500, 10, 20], (10, 20)),
      ('hmoveto', 22, <num>[500, 10], (10, 0)),
      ('vmoveto', 4, <num>[500, 20], (0, 20)),
    ];

    for (final (name, operator, operands, start) in cases) {
      final contour = glyphFor(<Object>[
        operands,
        operator,
        const <num>[1, 1],
        5,
        14,
      ]).contours.single;
      expect((contour.points[0], contour.points[1]), start, reason: name);
    }
  });

  test('escaped Type 2 stack operators produce deterministic values', () {
    final cases = <(String, List<Object>, double)>[
      (
        'and',
        <Object>[
          const <num>[1, 2],
          const (12, 3),
        ],
        1,
      ),
      (
        'or',
        <Object>[
          const <num>[0, 2],
          const (12, 4),
        ],
        1,
      ),
      (
        'not',
        <Object>[
          const <num>[0],
          const (12, 5),
        ],
        1,
      ),
      (
        'abs',
        <Object>[
          const <num>[-7],
          const (12, 9),
        ],
        7,
      ),
      (
        'add',
        <Object>[
          const <num>[2, 3],
          const (12, 10),
        ],
        5,
      ),
      (
        'sub',
        <Object>[
          const <num>[7, 2],
          const (12, 11),
        ],
        5,
      ),
      (
        'div',
        <Object>[
          const <num>[10, 2],
          const (12, 12),
        ],
        5,
      ),
      (
        'neg',
        <Object>[
          const <num>[-5],
          const (12, 14),
        ],
        5,
      ),
      (
        'eq',
        <Object>[
          const <num>[2, 2],
          const (12, 15),
        ],
        1,
      ),
      (
        'drop',
        <Object>[
          const <num>[99, 5],
          const (12, 18),
        ],
        99,
      ),
      (
        'put/get',
        <Object>[
          const <num>[42, 3],
          const (12, 20),
          const <num>[3],
          const (12, 21),
        ],
        42,
      ),
      (
        'ifelse',
        <Object>[
          const <num>[10, 20, 1, 2],
          const (12, 22),
        ],
        10,
      ),
      ('random', <Object>[const (12, 23)], 0.5),
      (
        'mul',
        <Object>[
          const <num>[2, 3],
          const (12, 24),
        ],
        6,
      ),
      (
        'sqrt',
        <Object>[
          const <num>[25],
          const (12, 26),
        ],
        5,
      ),
      (
        'dup',
        <Object>[
          const <num>[5],
          const (12, 27),
          const (12, 10),
        ],
        10,
      ),
      (
        'exch',
        <Object>[
          const <num>[2, 5],
          const (12, 28),
          const (12, 11),
        ],
        3,
      ),
      (
        'index',
        <Object>[
          const <num>[2, 5, 1],
          const (12, 29),
          const (12, 10),
          const (12, 10),
        ],
        9,
      ),
      (
        'roll',
        <Object>[
          const <num>[1, 2, 3, 3, 1],
          const (12, 30),
          const (12, 10),
          const (12, 11),
        ],
        0,
      ),
    ];

    for (final (name, operations, expected) in cases) {
      final contour = glyphFor(<Object>[
        ...operations,
        const <num>[0],
        21,
        const <num>[1, 0],
        5,
        14,
      ]).contours.single;
      expect(contour.points[0], expected, reason: name);
    }
  });

  test('shortint and fixed operands retain signed fractional values', () {
    final contour = glyphFor(<Object>[
      const <num>[2000, -2000],
      21,
      const <num>[1.5, 0],
      5,
      14,
    ]).contours.single;

    expect((contour.points[0], contour.points[1]), (2000, -2000));
    expect(explicitEndpoint(contour), (2001.5, -2000));
  });

  test('hintmask and cntrmask skip odd and multi-byte stem masks', () {
    final cases = <(int, List<num>, Uint8List)>[
      (19, <num>[0, 10], Uint8List.fromList(<int>[0xff])),
      (
        20,
        <num>[
          for (var stem = 0; stem < 9; stem++) ...<num>[stem * 20, 10],
        ],
        Uint8List.fromList(<int>[0xff, 0x80]),
      ),
    ];

    for (final (operator, stems, mask) in cases) {
      final glyph = glyphFor(<Object>[
        stems,
        1,
        operator,
        mask,
        const <num>[100, 100],
        21,
        const <num>[10, 0],
        5,
        14,
      ]);
      expect(glyph.contours, hasLength(1));
    }
  });

  test('CID FDSelect formats 0 and 3 choose per-dict local subroutines', () {
    for (final format in <int>[0, 3]) {
      final font = OpenTypeFont.parse(
        TestFontBuilder.cff1Cid(fdSelectFormat: format),
      );
      expect(
        cubicBounds(
          font.glyphForCodePoint(TestFontBuilder.cffCodePoint).contours,
        ),
        (100, 100, 200, 100),
        reason: 'format $format, Font DICT 0',
      );
      expect(
        cubicBounds(
          font
              .glyphForCodePoint(TestFontBuilder.cffAlternateCodePoint)
              .contours,
        ),
        (100, 100, 400, 100),
        reason: 'format $format, Font DICT 1',
      );
    }
  });

  test('all three Type 2 subroutine bias ranges resolve', () {
    for (final count in <int>[1, 1240, 33900]) {
      final glyph = OpenTypeFont.parse(
        TestFontBuilder.cff1WithSubroutineCount(count),
      ).glyphForCodePoint(TestFontBuilder.cffCodePoint);

      expect(cubicBounds(glyph.contours), (0, 0, 100, 0), reason: '$count');
    }
  });

  test('malformed Type 2 programs fail with typed exceptions', () {
    final programs = <(String, List<Object>)>[
      ('underflow', <Object>[const (12, 10), 14]),
      ('overflow', <Object>[List<num>.filled(49, 0, growable: false), 14]),
      (
        'division by zero',
        <Object>[
          const <num>[1, 0],
          const (12, 12),
          14,
        ],
      ),
      (
        'negative square root',
        <Object>[
          const <num>[-1],
          const (12, 26),
          14,
        ],
      ),
      (
        'bad transient index',
        <Object>[
          const <num>[32],
          const (12, 21),
          14,
        ],
      ),
      (
        'bad index',
        <Object>[
          const <num>[5, 1],
          const (12, 29),
          14,
        ],
      ),
      (
        'bad roll',
        <Object>[
          const <num>[1, 2, 3, 4, 0],
          const (12, 30),
          14,
        ],
      ),
      (
        'truncated hint mask',
        <Object>[
          const <num>[0, 10],
          1,
          19,
        ],
      ),
      ('unsupported operator', <Object>[2]),
      (
        'missing endchar',
        <Object>[
          const <num>[0, 0],
          21,
          const <num>[1, 0],
          5,
        ],
      ),
      (
        'bad subroutine index',
        <Object>[
          const <num>[-107],
          10,
          14,
        ],
      ),
    ];

    for (final (name, program) in programs) {
      expect(
        () => glyphFor(program),
        throwsA(isA<FontDataException>()),
        reason: name,
      );
    }

    expect(
      () => OpenTypeFont.parse(
        TestFontBuilder.cff1WithProgram(
          const <Object>[
            <num>[0, 0],
            21,
            <num>[-107],
            10,
            14,
          ],
          localSubroutines: const <List<Object>>[
            <Object>[
              <num>[1, 0],
              5,
            ],
          ],
        ),
      ).glyphForCodePoint(TestFontBuilder.cffCodePoint),
      throwsA(isA<FontDataException>()),
    );
  });

  test('malformed CFF INDEX, DICT, version, and FDSelect are typed', () {
    for (final fault in CffFault.values) {
      expect(
        () => OpenTypeFont.parse(
          TestFontBuilder.malformedCff1(fault),
        ).glyphForCodePoint(TestFontBuilder.cffCodePoint),
        throwsA(isA<FontDataException>()),
        reason: fault.name,
      );
    }
  });

  test('CFF DICT compact, short, long, and real operands parse', () {
    final glyph = OpenTypeFont.parse(
      TestFontBuilder.cff1WithDictEncodings(),
    ).glyphForCodePoint(TestFontBuilder.cffCodePoint);

    expect(cubicBounds(glyph.contours), (0, 0, 10, 0));
  });
}

GlyphOutline glyphFor(List<Object> program) => OpenTypeFont.parse(
  TestFontBuilder.cff1WithProgram(program),
).glyphForCodePoint(TestFontBuilder.cffCodePoint);

(double, double) explicitEndpoint(CubicContour contour) => (
  contour.points[contour.points.length - 8],
  contour.points[contour.points.length - 7],
);

(double, double, double, double) cubicBounds(List<CubicContour> contours) {
  var left = double.infinity;
  var top = double.infinity;
  var right = double.negativeInfinity;
  var bottom = double.negativeInfinity;
  for (final contour in contours) {
    final points = contour.points;
    for (var index = 0; index < points.length; index += 2) {
      left = left < points[index] ? left : points[index];
      top = top < points[index + 1] ? top : points[index + 1];
      right = right > points[index] ? right : points[index];
      bottom = bottom > points[index + 1] ? bottom : points[index + 1];
    }
  }
  return (left, top, right, bottom);
}
