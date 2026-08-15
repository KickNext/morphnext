import 'dart:typed_data';

const maxFontByteLength = 64 * 1024 * 1024;
const maxSfntTableCount = 128;
const maxGlyphPointCount = 65535;
const maxGlyphContourCount = 1024;
const maxCompositeComponentCount = 256;
const maxCompositeDepth = 16;
const maxType2StackDepth = 48;
const maxType2SubroutineDepth = 10;

/// A stable, contextual failure produced while reading font data.
final class FontDataException extends FormatException {
  const FontDataException(
    super.message, {
    this.tableTag,
    this.glyphId,
    this.assetKey,
    this.cause,
  });

  /// Table being decoded when the failure occurred.
  final String? tableTag;

  /// Glyph being decoded when the failure occurred.
  final int? glyphId;

  /// Bundled font asset being decoded when known.
  final String? assetKey;

  /// Original failure when wrapping a lower-level exception.
  final Object? cause;

  @override
  String toString() {
    final context = <String>[
      if (tableTag != null) 'table=$tableTag',
      if (glyphId != null) 'glyph=$glyphId',
      if (assetKey != null) 'asset=$assetKey',
    ];
    return context.isEmpty
        ? 'FontDataException: $message'
        : 'FontDataException (${context.join(', ')}): $message';
  }
}

/// Bounds-checked, big-endian access to a byte slice.
final class BinaryReader {
  /// Creates a view over [bytes].
  BinaryReader(this.bytes, {this.base = 0, int? length})
    : length = length ?? bytes.length - base,
      _data = ByteData.sublistView(bytes) {
    if (base < 0 || this.length < 0 || base > bytes.length - this.length) {
      throw const FontDataException('Slice is outside font data');
    }
  }

  /// Shared font storage.
  final Uint8List bytes;

  /// Absolute start of this slice in [bytes].
  final int base;

  /// Slice length in bytes.
  final int length;

  final ByteData _data;

  /// Ensures a relative byte range belongs to this slice.
  void require(int offset, int count) {
    if (offset < 0 || count < 0 || offset > length - count) {
      throw const FontDataException('Read is outside font data');
    }
  }

  /// Reads an unsigned byte.
  int uint8(int offset) {
    require(offset, 1);
    return _data.getUint8(base + offset);
  }

  /// Reads a signed byte.
  int int8(int offset) {
    require(offset, 1);
    return _data.getInt8(base + offset);
  }

  /// Reads an unsigned 16-bit integer.
  int uint16(int offset) {
    require(offset, 2);
    return _data.getUint16(base + offset, Endian.big);
  }

  /// Reads a signed 16-bit integer.
  int int16(int offset) {
    require(offset, 2);
    return _data.getInt16(base + offset, Endian.big);
  }

  /// Reads an unsigned 32-bit integer.
  int uint32(int offset) {
    require(offset, 4);
    return _data.getUint32(base + offset, Endian.big);
  }

  /// Reads a signed 32-bit integer.
  int int32(int offset) {
    require(offset, 4);
    return _data.getInt32(base + offset, Endian.big);
  }

  /// Reads a signed 2.14 fixed-point number.
  double f2Dot14(int offset) => int16(offset) / 16384;

  /// Reads a four-byte SFNT tag.
  String tag(int offset) {
    require(offset, 4);
    return String.fromCharCodes(bytes, base + offset, base + offset + 4);
  }

  /// Returns a checked nested view over the same storage.
  BinaryReader slice(int offset, int count) {
    require(offset, count);
    return BinaryReader(bytes, base: base + offset, length: count);
  }
}
