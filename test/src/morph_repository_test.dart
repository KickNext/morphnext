import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphnext/src/geometry/shape.dart';
import 'package:morphnext/src/morph_repository.dart';

import '../support/test_asset_bundle.dart';
import '../support/test_font_builder.dart';
import '../support/test_icons.dart';

void main() {
  test('variation coordinates produce distinct cached glyph shapes', () async {
    final bundle = TestAssetBundle.fonts(
      manifest: <String, List<String>>{
        testFontFamily: <String>['assets/variable.ttf'],
      },
      assets: <String, Uint8List>{
        'assets/variable.ttf': TestFontBuilder.variableTrueType(),
      },
    );
    final repository = MorphRepository.forBundle(bundle);
    final base = await repository.shapeFor(
      testQuadraticIcon,
      TextDirection.ltr,
    );
    const selection = (
      fill: null,
      weight: 650.0,
      grade: null,
      opticalSize: null,
      fontWeight: null,
    );
    final varied = await repository.shapeFor(
      testQuadraticIcon,
      TextDirection.ltr,
      selection,
    );

    expect(varied.contours.single.points, isNot(base.contours.single.points));
    expect(
      identical(
        varied,
        await repository.shapeFor(
          testQuadraticIcon,
          TextDirection.ltr,
          selection,
        ),
      ),
      isTrue,
    );
  });

  test(
    'normalizes height-one layout and mirrors directional RTL glyphs',
    () async {
      final repository = MorphRepository.forBundle(fixtureBundle());
      final ltr = await repository.shapeFor(
        testQuadraticIcon,
        TextDirection.ltr,
      );
      final rtl = await repository.shapeFor(
        testQuadraticIcon,
        TextDirection.rtl,
      );

      expect(ltr.contours, hasLength(1));
      expect(rtl.contours, hasLength(1));
      final ltrPoints = ltr.contours.single.points;
      final rtlPoints = rtl.contours.single.points;
      for (var index = 0; index < ltrPoints.length; index += 2) {
        var foundMirror = false;
        for (var candidate = 0; candidate < rtlPoints.length; candidate += 2) {
          if ((ltrPoints[index] + rtlPoints[candidate] - 1).abs() < 1e-12 &&
              (ltrPoints[index + 1] - rtlPoints[candidate + 1]).abs() < 1e-12) {
            foundMirror = true;
            break;
          }
        }
        expect(
          foundMirror,
          isTrue,
          reason: 'LTR sample $index has no reflected RTL counterpart',
        );
      }
    },
  );

  test('wide glyphs overflow from the left edge like Flutter Icon', () async {
    const family = 'WideFixtureIcons';
    const icon = IconData(
      TestFontBuilder.quadraticCodePoint,
      fontFamily: family,
    );
    final repository = MorphRepository.forBundle(
      TestAssetBundle.fonts(
        manifest: <String, List<String>>{
          family: <String>['assets/wide.ttf'],
        },
        assets: <String, Uint8List>{
          'assets/wide.ttf': TestFontBuilder.trueType(
            quadraticAdvanceWidth: 1400,
          ),
        },
      ),
    );

    final shape = await repository.shapeFor(icon, TextDirection.ltr);
    final xCoordinates = <double>[
      for (final contour in shape.exactContours!)
        for (var index = 0; index < contour.points.length; index += 2)
          contour.points[index],
    ];

    expect(xCoordinates.reduce(math.min), 0);
  });

  test('font glyphs always use OpenType non-zero fill semantics', () async {
    const family = 'MaterialIcons';
    const formerRepairCodePoint = 0xe522;
    const icon = IconData(formerRepairCodePoint, fontFamily: family);
    final repository = MorphRepository.forBundle(
      TestAssetBundle.fonts(
        manifest: <String, List<String>>{
          family: <String>['assets/material.ttf'],
        },
        assets: <String, Uint8List>{
          'assets/material.ttf': TestFontBuilder.trueType(
            additionalMappings: const <int, int>{formerRepairCodePoint: 1},
          ),
        },
      ),
    );

    final shape = await repository.shapeFor(icon, TextDirection.ltr);

    expect(shape.fillRule, MorphFillRule.nonZero);
  });

  test('glyph shapes and ordered pair plans are reused', () async {
    final bundle = fixtureBundle();
    final repository = MorphRepository.forBundle(bundle);

    final first = await repository.planFor(
      testQuadraticIcon,
      testCompositeIcon,
      TextDirection.ltr,
    );
    final second = await repository.planFor(
      testQuadraticIcon,
      testCompositeIcon,
      TextDirection.ltr,
    );

    expect(identical(first, second), isTrue);
    expect(bundle.loadCount('assets/icons.ttf'), 1);

    final reverse = await repository.planFor(
      testCompositeIcon,
      testQuadraticIcon,
      TextDirection.ltr,
    );
    expect(identical(first, reverse), isFalse);
  });

  test('sampling budget follows each contour complexity', () async {
    final repository = MorphRepository.forBundle(fixtureBundle());

    final quadratic = await repository.shapeFor(
      testQuadraticIcon,
      TextDirection.ltr,
    );
    final chevron = await repository.shapeFor(
      testChevronIcon,
      TextDirection.ltr,
    );

    expect(quadratic.contours.single.points.length ~/ 2, 64);
    expect(chevron.contours.single.points.length ~/ 2, 128);
  });

  test('unique shape streams evict old sampled geometry', () async {
    const shapeCount = 300;
    final repository = MorphRepository.forBundle(
      aliasedFixtureBundle(shapeCount),
    );
    final first = await repository.shapeFor(
      testAliasIcon(0),
      TextDirection.ltr,
    );

    for (var index = 1; index < shapeCount; index++) {
      await repository.shapeFor(testAliasIcon(index), TextDirection.ltr);
    }

    final rebuilt = await repository.shapeFor(
      testAliasIcon(0),
      TextDirection.ltr,
    );
    expect(identical(rebuilt, first), isFalse);
    expect(
      identical(
        await repository.shapeFor(testAliasIcon(0), TextDirection.ltr),
        rebuilt,
      ),
      isTrue,
    );
  });

  test('unique morph streams evict old pair plans', () async {
    const iconCount = 20;
    final repository = MorphRepository.forBundle(
      aliasedFixtureBundle(iconCount),
    );
    final first = await repository.planFor(
      testAliasIcon(0),
      testAliasIcon(1),
      TextDirection.ltr,
    );

    for (var from = 0; from < iconCount; from++) {
      for (var to = 0; to < iconCount; to++) {
        if (from == to || (from == 0 && to == 1)) continue;
        await repository.planFor(
          testAliasIcon(from),
          testAliasIcon(to),
          TextDirection.ltr,
        );
      }
    }

    final rebuilt = await repository.planFor(
      testAliasIcon(0),
      testAliasIcon(1),
      TextDirection.ltr,
    );
    expect(identical(rebuilt, first), isFalse);
    expect(
      identical(
        await repository.planFor(
          testAliasIcon(0),
          testAliasIcon(1),
          TextDirection.ltr,
        ),
        rebuilt,
      ),
      isTrue,
    );
  });

  test('empty outlines fail without poisoning the shape cache', () async {
    final repository = MorphRepository.forBundle(fixtureBundle());

    final first = repository.shapeFor(testEmptyIcon, TextDirection.ltr);
    await expectLater(first, throwsA(anything));
    final second = repository.shapeFor(testEmptyIcon, TextDirection.ltr);
    expect(identical(first, second), isFalse);
    await expectLater(second, throwsA(anything));
  });
}
