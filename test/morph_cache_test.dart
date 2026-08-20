import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphnext/morphnext.dart';
import 'package:morphnext/src/morph_repository.dart';

import 'support/test_asset_bundle.dart';
import 'support/test_font_builder.dart';
import 'support/test_icons.dart';

void main() {
  setUp(MorphCache.reset);
  tearDown(MorphCache.reset);

  test('exposes defaults and empty statistics after reset', () {
    expect(MorphCache.maxMorphs, MorphCache.defaultMaxMorphs);
    expect(MorphCache.maxBytes, MorphCache.defaultMaxBytes);
    expect(MorphCache.currentMorphs, 0);
    expect(MorphCache.currentBytes, 0);
  });

  test('configure requires positive limits', () {
    MorphCache.configure(maxMorphs: 7, maxBytes: 700);
    expect(
      () => MorphCache.configure(maxMorphs: 0, maxBytes: 1),
      throwsArgumentError,
    );
    expect(
      () => MorphCache.configure(maxMorphs: 1, maxBytes: 0),
      throwsArgumentError,
    );
    expect(
      () => MorphCache.configure(maxMorphs: -1, maxBytes: 1),
      throwsArgumentError,
    );
    expect(
      () => MorphCache.configure(maxMorphs: 1, maxBytes: -1),
      throwsArgumentError,
    );
    expect(MorphCache.maxMorphs, 7);
    expect(MorphCache.maxBytes, 700);
  });

  test('completed morphs update public statistics', () async {
    final repository = MorphRepository.forBundle(fixtureBundle());

    await repository.planFor(
      testQuadraticIcon,
      testCompositeIcon,
      TextDirection.ltr,
    );

    expect(MorphCache.currentMorphs, 1);
    expect(MorphCache.currentBytes, greaterThan(0));
  });

  test('maxMorphs evicts the least recently used completed morph', () async {
    MorphCache.configure(maxMorphs: 1, maxBytes: 1 << 20);
    final repository = MorphRepository.forBundle(aliasedFixtureBundle(3));
    final first = await repository.planFor(
      testAliasIcon(0),
      testAliasIcon(1),
      TextDirection.ltr,
    );

    await repository.planFor(
      testAliasIcon(1),
      testAliasIcon(2),
      TextDirection.ltr,
    );
    final rebuilt = await repository.planFor(
      testAliasIcon(0),
      testAliasIcon(1),
      TextDirection.ltr,
    );

    expect(MorphCache.currentMorphs, 1);
    expect(identical(rebuilt, first), isFalse);
  });

  test(
    'direction, font settings, and order identify distinct morphs',
    () async {
      final repository = MorphRepository.forBundle(fixtureBundle());
      const varied = (
        fill: null,
        weight: 650.0,
        grade: null,
        opticalSize: null,
        fontWeight: null,
      );

      await repository.planFor(
        testQuadraticIcon,
        testCompositeIcon,
        TextDirection.ltr,
      );
      await repository.planFor(
        testCompositeIcon,
        testQuadraticIcon,
        TextDirection.ltr,
      );
      await repository.planFor(
        testQuadraticIcon,
        testCompositeIcon,
        TextDirection.rtl,
      );
      await repository.planFor(
        testQuadraticIcon,
        testCompositeIcon,
        TextDirection.ltr,
        varied,
      );

      expect(MorphCache.currentMorphs, 4);
    },
  );

  test('interrupted one-off morphs are not retained', () async {
    final repository = MorphRepository.forBundle(fixtureBundle());
    final source = await repository.shapeFor(
      testQuadraticIcon,
      TextDirection.ltr,
    );

    await repository.planFromShape(
      source,
      testCompositeIcon,
      TextDirection.ltr,
    );

    expect(MorphCache.currentMorphs, 0);
    expect(MorphCache.currentBytes, 0);
  });

  test('configure replaces limits and clears retained morphs', () async {
    final repository = MorphRepository.forBundle(fixtureBundle());
    await repository.planFor(
      testQuadraticIcon,
      testCompositeIcon,
      TextDirection.ltr,
    );

    MorphCache.configure(maxMorphs: 50, maxBytes: 8 << 20);

    expect(MorphCache.maxMorphs, 50);
    expect(MorphCache.maxBytes, 8 << 20);
    expect(MorphCache.currentMorphs, 0);
    expect(MorphCache.currentBytes, 0);
  });

  test('clear preserves limits and disable prevents retention', () async {
    MorphCache.configure(maxMorphs: 50, maxBytes: 8 << 20);
    final repository = MorphRepository.forBundle(fixtureBundle());
    await repository.planFor(
      testQuadraticIcon,
      testCompositeIcon,
      TextDirection.ltr,
    );

    MorphCache.clear();

    expect(MorphCache.maxMorphs, 50);
    expect(MorphCache.maxBytes, 8 << 20);
    expect(MorphCache.currentMorphs, 0);

    MorphCache.disable();
    await repository.planFor(
      testQuadraticIcon,
      testCompositeIcon,
      TextDirection.ltr,
    );
    expect(MorphCache.maxMorphs, 0);
    expect(MorphCache.maxBytes, 0);
    expect(MorphCache.currentMorphs, 0);
    expect(MorphCache.currentBytes, 0);
  });

  test(
    'reset restores defaults, enables caching, and clears entries',
    () async {
      MorphCache.disable();
      final repository = MorphRepository.forBundle(fixtureBundle());
      await repository.planFor(
        testQuadraticIcon,
        testCompositeIcon,
        TextDirection.ltr,
      );

      MorphCache.reset();

      expect(MorphCache.maxMorphs, MorphCache.defaultMaxMorphs);
      expect(MorphCache.maxBytes, MorphCache.defaultMaxBytes);
      expect(MorphCache.currentMorphs, 0);
      await repository.planFor(
        testQuadraticIcon,
        testCompositeIcon,
        TextDirection.ltr,
      );
      expect(MorphCache.currentMorphs, 1);
    },
  );

  test('a morph larger than maxBytes is used but not retained', () async {
    MorphCache.configure(maxMorphs: 10, maxBytes: 1);
    final repository = MorphRepository.forBundle(fixtureBundle());

    final plan = await repository.planFor(
      testQuadraticIcon,
      testCompositeIcon,
      TextDirection.ltr,
    );

    expect(plan.items, isNotEmpty);
    expect(MorphCache.currentMorphs, 0);
    expect(MorphCache.currentBytes, 0);
  });

  test('cleared pending morph cannot return to the cache', () async {
    final bundle = DelayedTestAssetBundle.fonts(
      manifest: <String, List<String>>{
        testFontFamily: <String>['assets/icons.ttf'],
      },
      assets: <String, Uint8List>{
        'assets/icons.ttf': TestFontBuilder.trueType(),
      },
    )..delay('assets/icons.ttf');
    final future = MorphRepository.forBundle(
      bundle,
    ).planFor(testQuadraticIcon, testCompositeIcon, TextDirection.ltr);

    expect(MorphCache.currentMorphs, 0);
    expect(MorphCache.currentBytes, 0);
    MorphCache.clear();
    bundle.release('assets/icons.ttf');
    await future;

    expect(MorphCache.currentMorphs, 0);
    expect(MorphCache.currentBytes, 0);
  });
}
