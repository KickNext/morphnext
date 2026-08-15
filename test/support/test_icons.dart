import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:morphnext/src/font/font_asset_resolver.dart';

import 'test_asset_bundle.dart';
import 'test_font_builder.dart';

const testFontFamily = 'FixtureIcons';
const testFallbackFamily = 'FallbackIcons';
const testCffFamily = 'FixtureCffIcons';
const testAliasBaseCodePoint = 0xf000;

const testQuadraticIcon = IconData(
  TestFontBuilder.quadraticCodePoint,
  fontFamily: testFontFamily,
  matchTextDirection: true,
);
const testCompositeIcon = IconData(
  TestFontBuilder.compositeCodePoint,
  fontFamily: testFontFamily,
);
const testCompressedIcon = IconData(
  TestFontBuilder.compressedCodePoint,
  fontFamily: testFontFamily,
);
const testSquareWithHoleIcon = IconData(
  TestFontBuilder.squareWithHoleCodePoint,
  fontFamily: testFontFamily,
);
const testChevronIcon = IconData(
  TestFontBuilder.chevronCodePoint,
  fontFamily: testFontFamily,
);
const testRotatedChevronIcon = IconData(
  TestFontBuilder.rotatedChevronCodePoint,
  fontFamily: testFontFamily,
);
const testDiamondWithHoleIcon = IconData(
  TestFontBuilder.diamondWithHoleCodePoint,
  fontFamily: testFontFamily,
);
const testCffIcon = IconData(
  TestFontBuilder.cffCodePoint,
  fontFamily: testCffFamily,
);
const testEmptyIcon = IconData(
  TestFontBuilder.emptyCodePoint,
  fontFamily: testFontFamily,
);
const testFallbackIcon = IconData(
  TestFontBuilder.quadraticCodePoint,
  fontFamily: 'EmptyIcons',
  fontFamilyFallback: <String>[testFallbackFamily],
);

IconData testAliasIcon(int index) {
  // Dynamic fixture code points exercise cache churn without shipping them.
  // ignore: non_const_argument_for_const_parameter
  return IconData(testAliasBaseCodePoint + index, fontFamily: testFontFamily);
}

TestAssetBundle aliasedFixtureBundle(int aliasCount) => TestAssetBundle.fonts(
  manifest: <String, List<String>>{
    testFontFamily: <String>['assets/icons.ttf'],
  },
  assets: <String, Uint8List>{
    'assets/icons.ttf': TestFontBuilder.trueType(
      additionalMappings: <int, int>{
        for (var index = 0; index < aliasCount; index++)
          testAliasBaseCodePoint + index: 1 + index % 5,
      },
    ),
  },
);

TestAssetBundle fixtureBundle() => TestAssetBundle.fonts(
  manifest: <String, List<String>>{
    testFontFamily: <String>['assets/icons.ttf'],
    'EmptyIcons': <String>['assets/empty.ttf'],
    testFallbackFamily: <String>['assets/fallback.ttf'],
    testCffFamily: <String>['assets/icons.otf'],
  },
  assets: <String, Uint8List>{
    'assets/icons.ttf': TestFontBuilder.trueType(),
    'assets/empty.ttf': TestFontBuilder.trueType(includeIcons: false),
    'assets/fallback.ttf': TestFontBuilder.trueType(),
    'assets/icons.otf': TestFontBuilder.cff1(),
  },
);

FontAssetResolver fixtureResolver() => FontAssetResolver(fixtureBundle());

Future<void>? _testIconFonts;

Future<void> loadTestIconFonts() => _testIconFonts ??= _loadTestIconFonts();

Future<void> _loadTestIconFonts() async {
  await Future.wait<void>(<Future<void>>[
    (FontLoader(
      testFontFamily,
    )..addFont(_fontData(TestFontBuilder.trueType()))).load(),
    (FontLoader(
      testCffFamily,
    )..addFont(_fontData(TestFontBuilder.cff1()))).load(),
  ]);
}

Future<ByteData> _fontData(Uint8List bytes) async =>
    ByteData.sublistView(bytes);
