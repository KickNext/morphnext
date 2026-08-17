import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphnext/src/font/binary_reader.dart';
import 'package:morphnext/src/font/font_asset_resolver.dart';
import 'package:morphnext/src/font/open_type_font.dart';

import '../../support/test_asset_bundle.dart';
import '../../support/test_font_builder.dart';
import '../../support/test_icons.dart';

void main() {
  test('fontWeight selects the nearest declared static face', () async {
    final manifest = utf8.encode(
      jsonEncode(<Map<String, Object>>[
        <String, Object>{
          'family': testFontFamily,
          'fonts': <Map<String, Object>>[
            <String, Object>{'asset': 'assets/regular.ttf', 'weight': 400},
            <String, Object>{'asset': 'assets/bold.ttf', 'weight': 700},
          ],
        },
      ]),
    );
    final bundle = TestAssetBundle(<String, Uint8List>{
      'FontManifest.json': Uint8List.fromList(manifest),
      'assets/regular.ttf': TestFontBuilder.trueType(),
      'assets/bold.ttf': TestFontBuilder.trueType(),
    });

    await FontAssetResolver(bundle).resolve(testQuadraticIcon, const (
      fill: null,
      weight: null,
      grade: null,
      opticalSize: null,
      fontWeight: FontWeight.w700,
    ));

    expect(bundle.loadCount('assets/bold.ttf'), 1);
    expect(bundle.loadCount('assets/regular.ttf'), 0);
  });

  test(
    'package family is prefixed and the first containing face wins',
    () async {
      final bundle = TestAssetBundle.fonts(
        manifest: <String, List<String>>{
          'packages/acme/FixtureIcons': <String>[
            'assets/empty.ttf',
            'assets/icons.ttf',
          ],
        },
        assets: <String, Uint8List>{
          'assets/empty.ttf': TestFontBuilder.trueType(includeIcons: false),
          'assets/icons.ttf': TestFontBuilder.trueType(),
        },
      );
      final resolver = FontAssetResolver(bundle);

      await resolver.resolve(
        const IconData(
          TestFontBuilder.quadraticCodePoint,
          fontFamily: 'FixtureIcons',
          fontPackage: 'acme',
        ),
      );

      expect(bundle.loadCount('FontManifest.json'), 1);
      expect(bundle.loadCount('assets/empty.ttf'), 1);
      expect(bundle.loadCount('assets/icons.ttf'), 1);
    },
  );

  test('fallback families are searched in Flutter order', () async {
    final bundle = fixtureBundle();
    final resolver = FontAssetResolver(bundle);

    await resolver.resolve(testFallbackIcon);

    expect(bundle.loadCount('assets/empty.ttf'), 1);
    expect(bundle.loadCount('assets/fallback.ttf'), 1);
  });

  test('manifest, fonts, and resolved glyphs are reused', () async {
    final bundle = fixtureBundle();
    final resolver = FontAssetResolver(bundle);

    final first = await resolver.resolve(testQuadraticIcon);
    final second = await resolver.resolve(testQuadraticIcon);

    expect(identical(first, second), isTrue);
    expect(bundle.loadCount('FontManifest.json'), 1);
    expect(bundle.loadCount('assets/icons.ttf'), 1);
  });

  test('parsed font assets are evicted by the bounded cache', () async {
    const retainedFontCount = 32;
    final font = TestFontBuilder.trueType();
    final bundle = TestAssetBundle.fonts(
      manifest: <String, List<String>>{
        for (var index = 0; index <= retainedFontCount; index++)
          'Family$index': <String>['assets/font_$index.ttf'],
      },
      assets: <String, Uint8List>{
        for (var index = 0; index <= retainedFontCount; index++)
          'assets/font_$index.ttf': font,
      },
    );
    final resolver = FontAssetResolver(bundle);

    for (var index = 0; index <= retainedFontCount; index++) {
      await resolver.resolve(
        IconData(
          TestFontBuilder.quadraticCodePoint,
          fontFamily: 'Family$index',
        ),
      );
    }
    expect(bundle.loadCount('assets/font_0.ttf'), 1);

    await resolver.resolve(
      const IconData(
        TestFontBuilder.compositeCodePoint,
        fontFamily: 'Family0',
      ),
    );

    expect(bundle.loadCount('assets/font_0.ttf'), 2);
  });

  test('unique glyph streams evict old decoded outlines', () async {
    const glyphCount = 300;
    final resolver = FontAssetResolver(aliasedFixtureBundle(glyphCount));
    final first = await resolver.resolve(testAliasIcon(0));

    for (var index = 1; index < glyphCount; index++) {
      await resolver.resolve(testAliasIcon(index));
    }

    final rebuilt = await resolver.resolve(testAliasIcon(0));
    expect(identical(rebuilt, first), isFalse);
    expect(
      identical(await resolver.resolve(testAliasIcon(0)), rebuilt),
      isTrue,
    );
  });

  test('a failed asset future is removed so resolution can retry', () async {
    final bundle = fixtureBundle()..failNext('assets/icons.ttf');
    final resolver = FontAssetResolver(bundle);

    await expectLater(resolver.resolve(testQuadraticIcon), throwsA(anything));
    await resolver.resolve(testQuadraticIcon);

    expect(bundle.loadCount('assets/icons.ttf'), 2);
  });

  test('concurrent callers share manifest, font, and glyph futures', () async {
    final bundle = fixtureBundle();
    final resolver = FontAssetResolver(bundle);

    final results = await Future.wait<GlyphOutline>(<Future<GlyphOutline>>[
      resolver.resolve(testQuadraticIcon),
      resolver.resolve(testQuadraticIcon),
    ]);

    expect(identical(results[0], results[1]), isTrue);
    expect(bundle.loadCount('FontManifest.json'), 1);
    expect(bundle.loadCount('assets/icons.ttf'), 1);
  });

  test('a failed manifest future is removed so loading can retry', () async {
    final bundle = fixtureBundle()..failNext('FontManifest.json');
    final resolver = FontAssetResolver(bundle);

    await expectLater(resolver.resolve(testQuadraticIcon), throwsA(anything));
    await resolver.resolve(testQuadraticIcon);

    expect(bundle.loadCount('FontManifest.json'), 2);
  });

  test('manifest fields are validated before casting', () async {
    final bundle = TestAssetBundle(<String, Uint8List>{
      'FontManifest.json': Uint8List.fromList(
        utf8.encode('[{"family":7,"fonts":"bad"}]'),
      ),
    });

    await expectLater(
      FontAssetResolver(bundle).resolve(testQuadraticIcon),
      throwsA(isA<FontDataException>()),
    );
  });
}
