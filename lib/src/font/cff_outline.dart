import 'dart:math' as math;

import '../geometry/shape.dart';
import 'binary_reader.dart';
import 'open_type_font.dart';

const _charStringsOperator = 17;
const _privateOperator = 18;
const _subrsOperator = 19;
const _charStringTypeOperator = 0x0c06;
const _rosOperator = 0x0c1e;
const _fdArrayOperator = 0x0c24;
const _fdSelectOperator = 0x0c25;

/// Decodes one CFF1 Type 2 glyph into closed cubic contours.
GlyphOutline readCff1Glyph(OpenTypeFont font, int glyphId) {
  try {
    final cff = _Cff1Font.parse(font.requiredTable('CFF '), font.numGlyphs);
    return GlyphOutline(
      contours: cff.glyph(glyphId),
      advanceWidth: font.advanceWidth(glyphId),
      metrics: font.metrics,
    );
  } on FontDataException catch (error) {
    if (error.tableTag != null && error.glyphId != null) rethrow;
    throw FontDataException(
      error.message,
      tableTag: error.tableTag ?? 'CFF ',
      glyphId: error.glyphId ?? glyphId,
      cause: error,
    );
  }
}

final class _Cff1Font {
  const _Cff1Font({
    required this.charStrings,
    required this.globalSubroutines,
    required this.localSubroutinesByFontDict,
    required this.fontDictByGlyph,
  });

  factory _Cff1Font.parse(BinaryReader table, int glyphCount) {
    table.require(0, 4);
    if (table.uint8(0) != 1) {
      throw const FontDataException(
        'Unsupported CFF major version',
        tableTag: 'CFF ',
      );
    }
    final headerSize = table.uint8(2);
    final headerOffSize = table.uint8(3);
    if (headerSize < 4 ||
        headerSize > table.length ||
        headerOffSize < 1 ||
        headerOffSize > 4) {
      throw const FontDataException('Invalid CFF header', tableTag: 'CFF ');
    }

    var offset = headerSize;
    final names = _readIndex(table, offset);
    offset = names.nextOffset;
    final topDicts = _readIndex(table, offset);
    offset = topDicts.nextOffset;
    final strings = _readIndex(table, offset);
    offset = strings.nextOffset;
    final globalSubroutines = _readIndex(table, offset);
    if (names.objects.length != 1 || topDicts.objects.length != 1) {
      throw const FontDataException(
        'OpenType CFF must contain one top dictionary',
        tableTag: 'CFF ',
      );
    }

    final top = _parseDict(topDicts.objects.single);
    final charStringType = top[_charStringTypeOperator];
    if (charStringType != null &&
        (charStringType.length != 1 ||
            _dictInteger(charStringType.single, 'CharstringType') != 2)) {
      throw const FontDataException(
        'Only Type 2 CFF charstrings are supported',
        tableTag: 'CFF ',
      );
    }
    final charStringsOffset = _singleDictOffset(
      top,
      _charStringsOperator,
      'CharStrings',
    );
    final charStrings = _readIndex(table, charStringsOffset).objects;
    if (charStrings.length != glyphCount) {
      throw FontDataException(
        'CFF CharStrings count ${charStrings.length} does not match $glyphCount glyphs',
        tableTag: 'CFF ',
      );
    }

    final isCid = top.containsKey(_rosOperator);
    if (!isCid) {
      final localSubroutines = _readPrivateSubroutines(table, top);
      return _Cff1Font(
        charStrings: charStrings,
        globalSubroutines: globalSubroutines.objects,
        localSubroutinesByFontDict: <List<BinaryReader>>[localSubroutines],
        fontDictByGlyph: List<int>.filled(glyphCount, 0, growable: false),
      );
    }

    final ros = top[_rosOperator]!;
    if (ros.length != 3) {
      throw const FontDataException('Invalid CFF ROS', tableTag: 'CFF ');
    }
    for (final operand in ros) {
      if (_dictInteger(operand, 'ROS') < 0) {
        throw const FontDataException(
          'Negative CFF ROS operand',
          tableTag: 'CFF ',
        );
      }
    }
    final fdArrayOffset = _singleDictOffset(top, _fdArrayOperator, 'FDArray');
    final fontDicts = _readIndex(table, fdArrayOffset).objects;
    if (fontDicts.isEmpty || fontDicts.length > 256) {
      throw const FontDataException(
        'Invalid CFF Font DICT count',
        tableTag: 'CFF ',
      );
    }
    final localSubroutinesByFontDict = <List<BinaryReader>>[
      for (final fontDict in fontDicts)
        _readPrivateSubroutines(table, _parseDict(fontDict)),
    ];
    final fdSelectOffset = _singleDictOffset(
      top,
      _fdSelectOperator,
      'FDSelect',
    );
    final fontDictByGlyph = _readFdSelect(
      table,
      fdSelectOffset,
      glyphCount,
      fontDicts.length,
    );
    return _Cff1Font(
      charStrings: charStrings,
      globalSubroutines: globalSubroutines.objects,
      localSubroutinesByFontDict: localSubroutinesByFontDict,
      fontDictByGlyph: fontDictByGlyph,
    );
  }

  final List<BinaryReader> charStrings;
  final List<BinaryReader> globalSubroutines;
  final List<List<BinaryReader>> localSubroutinesByFontDict;
  final List<int> fontDictByGlyph;

  List<CubicContour> glyph(int glyphId) {
    if (glyphId < 0 || glyphId >= charStrings.length) {
      throw FontDataException(
        'Invalid CFF glyph id: $glyphId',
        glyphId: glyphId,
      );
    }
    final fontDict = fontDictByGlyph[glyphId];
    return _Type2Interpreter(
      globalSubroutines,
      localSubroutinesByFontDict[fontDict],
      glyphId,
    ).run(charStrings[glyphId]);
  }
}

final class _CffIndex {
  const _CffIndex(this.objects, this.nextOffset);

  final List<BinaryReader> objects;
  final int nextOffset;
}

_CffIndex _readIndex(BinaryReader table, int offset) {
  table.require(offset, 2);
  final count = table.uint16(offset);
  if (count == 0) return _CffIndex(const <BinaryReader>[], offset + 2);
  table.require(offset + 2, 1);
  final offSize = table.uint8(offset + 2);
  if (offSize < 1 || offSize > 4) {
    throw const FontDataException(
      'Invalid CFF INDEX offSize',
      tableTag: 'CFF ',
    );
  }
  final offsetsStart = offset + 3;
  final offsetCount = count + 1;
  table.require(offsetsStart, offSize * offsetCount);
  final offsets = List<int>.filled(offsetCount, 0, growable: false);
  for (var index = 0; index < offsetCount; index++) {
    var value = 0;
    for (var byte = 0; byte < offSize; byte++) {
      value = value * 256 + table.uint8(offsetsStart + offSize * index + byte);
    }
    offsets[index] = value;
  }
  if (offsets.first != 1) {
    throw const FontDataException(
      'CFF INDEX first offset is not one',
      tableTag: 'CFF ',
    );
  }
  for (var index = 1; index < offsets.length; index++) {
    if (offsets[index] < offsets[index - 1]) {
      throw const FontDataException(
        'CFF INDEX offsets are decreasing',
        tableTag: 'CFF ',
      );
    }
  }
  final dataStart = offsetsStart + offSize * offsetCount;
  final dataLength = offsets.last - 1;
  table.require(dataStart, dataLength);
  return _CffIndex(<BinaryReader>[
    for (var index = 0; index < count; index++)
      table.slice(
        dataStart + offsets[index] - 1,
        offsets[index + 1] - offsets[index],
      ),
  ], dataStart + dataLength);
}

Map<int, List<double>> _parseDict(BinaryReader dict) {
  final entries = <int, List<double>>{};
  final operands = <double>[];
  var cursor = 0;
  while (cursor < dict.length) {
    final byte = dict.uint8(cursor++);
    if (byte == 28 || byte == 29 || byte == 30 || byte >= 32) {
      final decoded = _readDictNumber(dict, cursor, byte);
      cursor = decoded.$2;
      if (operands.length >= maxType2StackDepth) {
        throw const FontDataException(
          'CFF DICT operand stack overflow',
          tableTag: 'CFF ',
        );
      }
      operands.add(decoded.$1);
      continue;
    }
    if (byte > 21) {
      throw const FontDataException('Reserved CFF DICT byte', tableTag: 'CFF ');
    }
    final operator = byte == 12 ? 0x0c00 | dict.uint8(cursor++) : byte;
    entries[operator] = List<double>.unmodifiable(operands);
    operands.clear();
  }
  if (operands.isNotEmpty) {
    throw const FontDataException(
      'CFF DICT ends without an operator',
      tableTag: 'CFF ',
    );
  }
  return entries;
}

(double, int) _readDictNumber(BinaryReader dict, int cursor, int first) {
  if (first == 28) return (dict.int16(cursor).toDouble(), cursor + 2);
  if (first == 29) return (dict.int32(cursor).toDouble(), cursor + 4);
  if (first == 30) {
    final value = StringBuffer();
    var terminated = false;
    while (!terminated) {
      final byte = dict.uint8(cursor++);
      for (final nibble in <int>[byte >> 4, byte & 0x0f]) {
        if (nibble == 0x0f) {
          terminated = true;
          break;
        }
        value.write(switch (nibble) {
          >= 0 && <= 9 => nibble.toString(),
          0x0a => '.',
          0x0b => 'E',
          0x0c => 'E-',
          0x0e => '-',
          _ => throw const FontDataException(
            'Reserved CFF real-number nibble',
            tableTag: 'CFF ',
          ),
        });
      }
    }
    final parsed = double.tryParse(value.toString());
    if (parsed == null || !parsed.isFinite) {
      throw const FontDataException(
        'Invalid CFF real number',
        tableTag: 'CFF ',
      );
    }
    return (parsed, cursor);
  }
  if (first >= 32 && first <= 246) {
    return ((first - 139).toDouble(), cursor);
  }
  if (first >= 247 && first <= 250) {
    return (
      ((first - 247) * 256 + dict.uint8(cursor) + 108).toDouble(),
      cursor + 1,
    );
  }
  if (first >= 251 && first <= 254) {
    return (
      (-(first - 251) * 256 - dict.uint8(cursor) - 108).toDouble(),
      cursor + 1,
    );
  }
  throw const FontDataException('Invalid CFF DICT operand', tableTag: 'CFF ');
}

int _dictInteger(double value, String label) {
  if (!value.isFinite || value != value.roundToDouble()) {
    throw FontDataException('$label must be an integer', tableTag: 'CFF ');
  }
  return value.toInt();
}

int _singleDictOffset(Map<int, List<double>> dict, int operator, String label) {
  final operands = dict[operator];
  if (operands == null || operands.length != 1) {
    throw FontDataException(
      'Missing or invalid CFF $label offset',
      tableTag: 'CFF ',
    );
  }
  final offset = _dictInteger(operands.single, label);
  if (offset < 0) {
    throw FontDataException('Negative CFF $label offset', tableTag: 'CFF ');
  }
  return offset;
}

List<BinaryReader> _readPrivateSubroutines(
  BinaryReader table,
  Map<int, List<double>> dict,
) {
  final private = dict[_privateOperator];
  if (private == null) return const <BinaryReader>[];
  if (private.length != 2) {
    throw const FontDataException(
      'Invalid CFF Private DICT entry',
      tableTag: 'CFF ',
    );
  }
  final size = _dictInteger(private[0], 'Private size');
  final offset = _dictInteger(private[1], 'Private offset');
  if (size < 0 || offset < 0) {
    throw const FontDataException(
      'Negative CFF Private DICT range',
      tableTag: 'CFF ',
    );
  }
  final privateDict = _parseDict(table.slice(offset, size));
  final subrs = privateDict[_subrsOperator];
  if (subrs == null) return const <BinaryReader>[];
  if (subrs.length != 1) {
    throw const FontDataException(
      'Invalid CFF local Subrs offset',
      tableTag: 'CFF ',
    );
  }
  final relativeOffset = _dictInteger(subrs.single, 'Subrs');
  if (relativeOffset < size) {
    throw const FontDataException(
      'CFF local Subrs overlaps its Private DICT',
      tableTag: 'CFF ',
    );
  }
  return _readIndex(table, offset + relativeOffset).objects;
}

List<int> _readFdSelect(
  BinaryReader table,
  int offset,
  int glyphCount,
  int fontDictCount,
) {
  final format = table.uint8(offset);
  if (format == 0) {
    table.require(offset + 1, glyphCount);
    return List<int>.generate(glyphCount, (glyphId) {
      final fontDict = table.uint8(offset + 1 + glyphId);
      if (fontDict >= fontDictCount) {
        throw const FontDataException(
          'CFF FDSelect references an invalid Font DICT',
          tableTag: 'CFF ',
        );
      }
      return fontDict;
    }, growable: false);
  }
  if (format != 3) {
    throw FontDataException(
      'Unsupported CFF FDSelect format: $format',
      tableTag: 'CFF ',
    );
  }
  final rangeCount = table.uint16(offset + 1);
  if (rangeCount == 0 || rangeCount > glyphCount) {
    throw const FontDataException(
      'Invalid CFF FDSelect range count',
      tableTag: 'CFF ',
    );
  }
  table.require(offset + 3, 3 * rangeCount + 2);
  final starts = List<int>.filled(rangeCount, 0, growable: false);
  final fontDicts = List<int>.filled(rangeCount, 0, growable: false);
  for (var index = 0; index < rangeCount; index++) {
    starts[index] = table.uint16(offset + 3 + 3 * index);
    fontDicts[index] = table.uint8(offset + 5 + 3 * index);
    if (fontDicts[index] >= fontDictCount ||
        (index == 0
            ? starts[index] != 0
            : starts[index] <= starts[index - 1])) {
      throw const FontDataException(
        'Invalid CFF FDSelect range',
        tableTag: 'CFF ',
      );
    }
  }
  final sentinel = table.uint16(offset + 3 + 3 * rangeCount);
  if (sentinel != glyphCount || starts.last >= sentinel) {
    throw const FontDataException(
      'Invalid CFF FDSelect sentinel',
      tableTag: 'CFF ',
    );
  }
  final selection = List<int>.filled(glyphCount, 0, growable: false);
  for (var range = 0; range < rangeCount; range++) {
    final end = range + 1 < rangeCount ? starts[range + 1] : sentinel;
    selection.fillRange(starts[range], end, fontDicts[range]);
  }
  return selection;
}

final class _Type2Interpreter {
  _Type2Interpreter(
    this.globalSubroutines,
    this.localSubroutines,
    this.glyphId,
  );

  final List<BinaryReader> globalSubroutines;
  final List<BinaryReader> localSubroutines;
  final int glyphId;
  final List<double> stack = <double>[];
  final List<double> transient = List<double>.filled(32, 0, growable: false);
  final List<CubicContour> contours = <CubicContour>[];

  CubicContourBuilder? builder;
  var x = 0.0;
  var y = 0.0;
  var contourSegments = 0;
  var totalSegments = 0;
  var stemCount = 0;
  var widthSeen = false;
  var operationsRemaining = maxGlyphPointCount * 16;

  List<CubicContour> run(BinaryReader charString) {
    if (_execute(charString, 0, isSubroutine: false) != _Execution.endChar) {
      throw FontDataException('CFF glyph is missing endchar', glyphId: glyphId);
    }
    return List<CubicContour>.unmodifiable(contours);
  }

  _Execution _execute(
    BinaryReader code,
    int depth, {
    required bool isSubroutine,
  }) {
    var cursor = 0;
    while (cursor < code.length) {
      if (operationsRemaining-- <= 0) {
        throw FontDataException(
          'Type 2 operation limit exceeded',
          glyphId: glyphId,
        );
      }
      final byte = code.uint8(cursor++);
      if (byte == 28 || byte >= 32) {
        final number = _readType2Number(code, cursor, byte);
        cursor = number.$2;
        _push(number.$1);
        continue;
      }

      switch (byte) {
        case 1:
        case 3:
        case 18:
        case 23:
          _consumeStems();
        case 4:
          final values = _moveArguments(1);
          _move(0, values.single);
        case 5:
          _relativeLines(_takeStack());
        case 6:
        case 7:
          _alternatingLines(_takeStack(), startsHorizontal: byte == 6);
        case 8:
          _rrCurves(_takeStack());
        case 10:
        case 29:
          final subroutines = byte == 10 ? localSubroutines : globalSubroutines;
          final subroutineNumber = _popInteger('subroutine index');
          if (depth >= maxType2SubroutineDepth) {
            throw FontDataException(
              'Type 2 subroutine recursion limit exceeded',
              glyphId: glyphId,
            );
          }
          final index = subroutineNumber + _subroutineBias(subroutines.length);
          if (index < 0 || index >= subroutines.length) {
            throw FontDataException(
              'Type 2 subroutine index is out of range',
              glyphId: glyphId,
            );
          }
          final result = _execute(
            subroutines[index],
            depth + 1,
            isSubroutine: true,
          );
          if (result == _Execution.endChar) return result;
        case 11:
          if (!isSubroutine) {
            throw FontDataException(
              'Type 2 return outside a subroutine',
              glyphId: glyphId,
            );
          }
          return _Execution.returned;
        case 12:
          _escaped(code.uint8(cursor++));
        case 14:
          _consumeEndCharWidth();
          _closeContour();
          return _Execution.endChar;
        case 19:
        case 20:
          _consumeStems();
          final maskLength = (stemCount + 7) ~/ 8;
          code.require(cursor, maskLength);
          cursor += maskLength;
        case 21:
          final values = _moveArguments(2);
          _move(values[0], values[1]);
        case 22:
          final values = _moveArguments(1);
          _move(values.single, 0);
        case 24:
          _curveLine(_takeStack());
        case 25:
          _lineCurve(_takeStack());
        case 26:
          _vvCurves(_takeStack());
        case 27:
          _hhCurves(_takeStack());
        case 30:
        case 31:
          _alternatingCurves(_takeStack(), startsHorizontal: byte == 31);
        default:
          throw FontDataException(
            'Unsupported Type 2 operator: $byte',
            glyphId: glyphId,
          );
      }
    }
    if (isSubroutine) {
      throw FontDataException(
        'Type 2 subroutine is missing return',
        glyphId: glyphId,
      );
    }
    throw FontDataException('CFF glyph is missing endchar', glyphId: glyphId);
  }

  void _escaped(int operator) {
    switch (operator) {
      case 3:
        final b = _pop();
        final a = _pop();
        _push(a != 0 && b != 0 ? 1 : 0);
      case 4:
        final b = _pop();
        final a = _pop();
        _push(a != 0 || b != 0 ? 1 : 0);
      case 5:
        _push(_pop() == 0 ? 1 : 0);
      case 9:
        _push(_pop().abs());
      case 10:
        final b = _pop();
        _push(_pop() + b);
      case 11:
        final b = _pop();
        _push(_pop() - b);
      case 12:
        final divisor = _pop();
        if (divisor == 0) {
          throw FontDataException('Type 2 division by zero', glyphId: glyphId);
        }
        _push(_pop() / divisor);
      case 14:
        _push(-_pop());
      case 15:
        final b = _pop();
        _push(_pop() == b ? 1 : 0);
      case 18:
        _pop();
      case 20:
        final index = _popInteger('transient index');
        final value = _pop();
        _checkTransientIndex(index);
        transient[index] = value;
      case 21:
        final index = _popInteger('transient index');
        _checkTransientIndex(index);
        _push(transient[index]);
      case 22:
        final value2 = _pop();
        final value1 = _pop();
        final choice2 = _pop();
        final choice1 = _pop();
        _push(value1 <= value2 ? choice1 : choice2);
      case 23:
        _push(0.5);
      case 24:
        final b = _pop();
        _push(_pop() * b);
      case 26:
        final value = _pop();
        if (value < 0) {
          throw FontDataException(
            'Type 2 square root of a negative value',
            glyphId: glyphId,
          );
        }
        _push(math.sqrt(value));
      case 27:
        _push(_peek(0));
      case 28:
        final top = _pop();
        final below = _pop();
        _push(top);
        _push(below);
      case 29:
        final index = _popInteger('index');
        if (index < 0 || index >= stack.length) {
          throw FontDataException('Invalid Type 2 index', glyphId: glyphId);
        }
        _push(_peek(index));
      case 30:
        final shift = _popInteger('roll shift');
        final count = _popInteger('roll count');
        if (count < 0 || count > stack.length) {
          throw FontDataException('Invalid Type 2 roll', glyphId: glyphId);
        }
        if (count > 1) {
          final normalized = ((shift % count) + count) % count;
          if (normalized != 0) {
            final start = stack.length - count;
            final values = stack.sublist(start);
            stack.replaceRange(start, stack.length, <double>[
              ...values.skip(count - normalized),
              ...values.take(count - normalized),
            ]);
          }
        }
      case 34:
        _hflex(_takeStack());
      case 35:
        _flex(_takeStack());
      case 36:
        _hflex1(_takeStack());
      case 37:
        _flex1(_takeStack());
      default:
        throw FontDataException(
          'Unsupported escaped Type 2 operator: $operator',
          glyphId: glyphId,
        );
    }
  }

  void _consumeStems() {
    if (!widthSeen && stack.length.isOdd) stack.removeAt(0);
    widthSeen = true;
    if (stack.length.isOdd) {
      throw FontDataException('Invalid Type 2 stem operands', glyphId: glyphId);
    }
    stemCount += stack.length ~/ 2;
    stack.clear();
  }

  List<double> _moveArguments(int count) {
    if (!widthSeen && stack.length == count + 1) stack.removeAt(0);
    widthSeen = true;
    if (stack.length != count) {
      throw FontDataException('Invalid Type 2 move operands', glyphId: glyphId);
    }
    return _takeStack();
  }

  void _consumeEndCharWidth() {
    if (!widthSeen && (stack.length == 1 || stack.length == 5)) {
      stack.removeAt(0);
    }
    widthSeen = true;
    if (stack.isNotEmpty) {
      throw FontDataException(
        'Type 2 seac endchar is unsupported',
        glyphId: glyphId,
      );
    }
  }

  void _move(double dx, double dy) {
    _closeContour();
    x += dx;
    y += dy;
    _checkFinitePoint(x, y);
    builder = CubicContourBuilder()..moveTo(x, y);
    contourSegments = 0;
  }

  void _relativeLines(List<double> values) {
    if (values.length < 2 || values.length.isOdd) {
      throw FontDataException(
        'Invalid Type 2 rlineto operands',
        glyphId: glyphId,
      );
    }
    for (var index = 0; index < values.length; index += 2) {
      _line(values[index], values[index + 1]);
    }
  }

  void _alternatingLines(
    List<double> values, {
    required bool startsHorizontal,
  }) {
    if (values.isEmpty) {
      throw FontDataException('Empty Type 2 line operator', glyphId: glyphId);
    }
    var horizontal = startsHorizontal;
    for (final value in values) {
      _line(horizontal ? value : 0, horizontal ? 0 : value);
      horizontal = !horizontal;
    }
  }

  void _rrCurves(List<double> values) {
    if (values.length < 6 || values.length % 6 != 0) {
      throw FontDataException(
        'Invalid Type 2 rrcurveto operands',
        glyphId: glyphId,
      );
    }
    for (var index = 0; index < values.length; index += 6) {
      _curve(
        values[index],
        values[index + 1],
        values[index + 2],
        values[index + 3],
        values[index + 4],
        values[index + 5],
      );
    }
  }

  void _curveLine(List<double> values) {
    if (values.length < 8 || (values.length - 2) % 6 != 0) {
      throw FontDataException(
        'Invalid Type 2 rcurveline operands',
        glyphId: glyphId,
      );
    }
    _rrCurves(values.sublist(0, values.length - 2));
    _line(values[values.length - 2], values.last);
  }

  void _lineCurve(List<double> values) {
    if (values.length < 8 || (values.length - 6).isOdd) {
      throw FontDataException(
        'Invalid Type 2 rlinecurve operands',
        glyphId: glyphId,
      );
    }
    _relativeLines(values.sublist(0, values.length - 6));
    _rrCurves(values.sublist(values.length - 6));
  }

  void _hhCurves(List<double> values) {
    if (values.length < 4 || values.length % 4 > 1) {
      throw FontDataException(
        'Invalid Type 2 hhcurveto operands',
        glyphId: glyphId,
      );
    }
    var index = 0;
    var firstDy = values.length.isOdd ? values[index++] : 0.0;
    while (index < values.length) {
      _curve(
        values[index],
        firstDy,
        values[index + 1],
        values[index + 2],
        values[index + 3],
        0,
      );
      firstDy = 0;
      index += 4;
    }
  }

  void _vvCurves(List<double> values) {
    if (values.length < 4 || values.length % 4 > 1) {
      throw FontDataException(
        'Invalid Type 2 vvcurveto operands',
        glyphId: glyphId,
      );
    }
    var index = 0;
    var firstDx = values.length.isOdd ? values[index++] : 0.0;
    while (index < values.length) {
      _curve(
        firstDx,
        values[index],
        values[index + 1],
        values[index + 2],
        0,
        values[index + 3],
      );
      firstDx = 0;
      index += 4;
    }
  }

  void _alternatingCurves(
    List<double> values, {
    required bool startsHorizontal,
  }) {
    if (values.length < 4 ||
        (values.length % 4 != 0 && values.length % 4 != 1)) {
      throw FontDataException(
        'Invalid alternating Type 2 curve operands',
        glyphId: glyphId,
      );
    }
    var index = 0;
    var horizontal = startsHorizontal;
    while (index < values.length) {
      final remaining = values.length - index;
      final hasFinalDelta = remaining == 5;
      if (horizontal) {
        _curve(
          values[index],
          0,
          values[index + 1],
          values[index + 2],
          hasFinalDelta ? values[index + 4] : 0,
          values[index + 3],
        );
      } else {
        _curve(
          0,
          values[index],
          values[index + 1],
          values[index + 2],
          values[index + 3],
          hasFinalDelta ? values[index + 4] : 0,
        );
      }
      index += hasFinalDelta ? 5 : 4;
      horizontal = !horizontal;
    }
  }

  void _hflex(List<double> values) {
    _expectCount(values, 7, 'hflex');
    _curve(values[0], 0, values[1], values[2], values[3], 0);
    _curve(values[4], 0, values[5], -values[2], values[6], 0);
  }

  void _flex(List<double> values) {
    _expectCount(values, 13, 'flex');
    _curve(values[0], values[1], values[2], values[3], values[4], values[5]);
    _curve(values[6], values[7], values[8], values[9], values[10], values[11]);
  }

  void _hflex1(List<double> values) {
    _expectCount(values, 9, 'hflex1');
    _curve(values[0], values[1], values[2], values[3], values[4], 0);
    _curve(
      values[5],
      0,
      values[6],
      values[7],
      values[8],
      -(values[1] + values[3] + values[7]),
    );
  }

  void _flex1(List<double> values) {
    _expectCount(values, 11, 'flex1');
    final sumX = values[0] + values[2] + values[4] + values[6] + values[8];
    final sumY = values[1] + values[3] + values[5] + values[7] + values[9];
    final lastX = sumX.abs() > sumY.abs() ? values[10] : -sumX;
    final lastY = sumX.abs() > sumY.abs() ? -sumY : values[10];
    _curve(values[0], values[1], values[2], values[3], values[4], values[5]);
    _curve(values[6], values[7], values[8], values[9], lastX, lastY);
  }

  void _line(double dx, double dy) {
    _requirePath();
    x += dx;
    y += dy;
    _checkFinitePoint(x, y);
    builder!.lineTo(x, y);
    _countSegment();
  }

  void _curve(
    double dx1,
    double dy1,
    double dx2,
    double dy2,
    double dx3,
    double dy3,
  ) {
    _requirePath();
    final control1X = x + dx1;
    final control1Y = y + dy1;
    final control2X = control1X + dx2;
    final control2Y = control1Y + dy2;
    x = control2X + dx3;
    y = control2Y + dy3;
    _checkFinitePoint(control1X, control1Y);
    _checkFinitePoint(control2X, control2Y);
    _checkFinitePoint(x, y);
    builder!.cubicTo(control1X, control1Y, control2X, control2Y, x, y);
    _countSegment();
  }

  void _countSegment() {
    contourSegments++;
    if (++totalSegments > maxGlyphPointCount) {
      throw FontDataException(
        'CFF glyph exceeds the geometry limit',
        glyphId: glyphId,
      );
    }
  }

  void _closeContour() {
    final active = builder;
    if (active != null && contourSegments > 0) {
      if (contours.length >= maxGlyphContourCount) {
        throw FontDataException(
          'CFF glyph exceeds the contour limit',
          glyphId: glyphId,
        );
      }
      contours.add(active.close());
    }
    builder = null;
    contourSegments = 0;
  }

  void _requirePath() {
    if (builder == null) {
      throw FontDataException(
        'Type 2 drawing operator precedes moveto',
        glyphId: glyphId,
      );
    }
  }

  void _push(double value) {
    if (!value.isFinite) {
      throw FontDataException('Non-finite Type 2 value', glyphId: glyphId);
    }
    if (stack.length >= maxType2StackDepth) {
      throw FontDataException('Type 2 stack overflow', glyphId: glyphId);
    }
    stack.add(value);
  }

  double _pop() {
    if (stack.isEmpty) {
      throw FontDataException('Type 2 stack underflow', glyphId: glyphId);
    }
    return stack.removeLast();
  }

  double _peek(int index) {
    if (index < 0 || index >= stack.length) {
      throw FontDataException(
        'Type 2 stack index is invalid',
        glyphId: glyphId,
      );
    }
    return stack[stack.length - 1 - index];
  }

  int _popInteger(String label) {
    final value = _pop();
    if (value != value.roundToDouble()) {
      throw FontDataException(
        'Type 2 $label is not an integer',
        glyphId: glyphId,
      );
    }
    return value.toInt();
  }

  List<double> _takeStack() {
    final values = List<double>.of(stack);
    stack.clear();
    return values;
  }

  void _checkTransientIndex(int index) {
    if (index < 0 || index >= transient.length) {
      throw FontDataException(
        'Type 2 transient index is out of range',
        glyphId: glyphId,
      );
    }
  }

  void _expectCount(List<double> values, int count, String operator) {
    if (values.length != count) {
      throw FontDataException(
        'Invalid Type 2 $operator operands',
        glyphId: glyphId,
      );
    }
  }

  void _checkFinitePoint(double pointX, double pointY) {
    if (!pointX.isFinite || !pointY.isFinite) {
      throw FontDataException('Non-finite CFF point', glyphId: glyphId);
    }
  }
}

(double, int) _readType2Number(BinaryReader code, int cursor, int first) {
  if (first == 28) return (code.int16(cursor).toDouble(), cursor + 2);
  if (first >= 32 && first <= 246) {
    return ((first - 139).toDouble(), cursor);
  }
  if (first >= 247 && first <= 250) {
    return (
      ((first - 247) * 256 + code.uint8(cursor) + 108).toDouble(),
      cursor + 1,
    );
  }
  if (first >= 251 && first <= 254) {
    return (
      (-(first - 251) * 256 - code.uint8(cursor) - 108).toDouble(),
      cursor + 1,
    );
  }
  if (first == 255) return (code.int32(cursor) / 65536, cursor + 4);
  throw const FontDataException('Invalid Type 2 number');
}

int _subroutineBias(int count) => count < 1240
    ? 107
    : count < 33900
    ? 1131
    : 32768;

enum _Execution { returned, endChar }
