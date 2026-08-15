import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

final class TolerantGoldenComparator extends LocalFileComparator {
  TolerantGoldenComparator(super.testFile);

  static const maximumDifferingPixelFraction = 0.005;
  static const maximumChannelDelta = 8;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final goldenBytes = Uint8List.fromList(await getGoldenBytes(golden));
    if (listEquals(imageBytes, goldenBytes)) return true;

    final actual = await _decode(imageBytes);
    final expected = await _decode(goldenBytes);
    try {
      if (actual.width == expected.width &&
          actual.height == expected.height &&
          _differingFraction(actual.bytes, expected.bytes) <=
              maximumDifferingPixelFraction) {
        return true;
      }
    } finally {
      actual.image.dispose();
      expected.image.dispose();
    }

    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      goldenBytes,
    );
    final output = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(
      '$output\nAllowed at most 0.5% of pixels with a channel delta above 8.',
    );
  }
}

double _differingFraction(Uint8List actual, Uint8List expected) {
  if (actual.length != expected.length || actual.length % 4 != 0) return 1;
  var differingPixels = 0;
  for (var offset = 0; offset < actual.length; offset += 4) {
    var differs = false;
    for (var channel = 0; channel < 4; channel++) {
      if ((actual[offset + channel] - expected[offset + channel]).abs() >
          TolerantGoldenComparator.maximumChannelDelta) {
        differs = true;
        break;
      }
    }
    if (differs) differingPixels++;
  }
  return differingPixels / (actual.length ~/ 4);
}

Future<_DecodedImage> _decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  try {
    final image = (await codec.getNextFrame()).image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) {
      image.dispose();
      throw StateError('Could not decode golden pixels');
    }
    return _DecodedImage(
      image,
      Uint8List.fromList(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      ),
    );
  } finally {
    codec.dispose();
  }
}

final class _DecodedImage {
  const _DecodedImage(this.image, this.bytes);

  final ui.Image image;
  final Uint8List bytes;
  int get width => image.width;
  int get height => image.height;
}
