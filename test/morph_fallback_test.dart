import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphnext/morphnext.dart';

import 'morph_icon_test.dart' show testHost;
import 'support/test_asset_bundle.dart';
import 'support/test_icons.dart';

const _missing = IconData(0xe900, fontFamily: 'MissingFont');

void main() {
  for (final implicit in [false, true]) {
    testWidgets(
      'fallback reports once and remains usable (implicit=$implicit)',
      (tester) async {
        final bundle = fixtureBundle();
        final failures = <MorphFallbackDetails>[];
        var ended = 0;
        Widget icon(IconData target) => implicit
            ? AnimatedMorphIcon(
                icon: target,
                onFallback: failures.add,
                onEnd: () => ended++,
              )
            : MorphIcon(
                from: testQuadraticIcon,
                to: target,
                progress: const AlwaysStoppedAnimation(1),
                onFallback: failures.add,
              );
        await tester.pumpWidget(testHost(bundle, icon(testQuadraticIcon)));
        await tester.pumpWidget(testHost(bundle, icon(_missing)));
        await tester.pumpAndSettle();
        expect(failures, hasLength(1));
        expect(failures.single.from, testQuadraticIcon);
        expect(failures.single.to, _missing);
        expect(failures.single.error, isA<FormatException>());
        expect(failures.single.stackTrace.toString(), isNotEmpty);
        expect(find.byIcon(_missing), findsOneWidget);
        expect(ended, implicit ? 1 : 0);
        await tester.pumpWidget(testHost(bundle, icon(_missing)));
        await tester.pumpAndSettle();
        expect(failures, hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );

    for (final dispose in [false, true]) {
      testWidgets(
        'late failure is ignored (implicit=$implicit, dispose=$dispose)',
        (tester) async {
          final bundle = DelayedTestAssetBundle.fonts(
            manifest: {
              testFontFamily: ['broken.ttf'],
            },
            assets: {'broken.ttf': Uint8List(4)},
          )..delay('broken.ttf');
          final failures = <MorphFallbackDetails>[];
          Widget icon(IconData target) => implicit
              ? AnimatedMorphIcon(icon: target, onFallback: failures.add)
              : MorphIcon(
                  from: testQuadraticIcon,
                  to: target,
                  progress: const AlwaysStoppedAnimation(1),
                  onFallback: failures.add,
                );
          await tester.pumpWidget(testHost(bundle, icon(testQuadraticIcon)));
          await tester.pumpWidget(testHost(bundle, icon(testCompositeIcon)));
          await tester.pump();
          await tester.pumpWidget(
            dispose
                ? const SizedBox()
                : testHost(bundle, icon(testQuadraticIcon)),
          );
          bundle.release('broken.ttf');
          await tester.pumpAndSettle();
          expect(failures, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('throwing callback is reported without stopping fallback', (
    tester,
  ) async {
    final bundle = fixtureBundle();
    var ended = 0;
    await tester.pumpWidget(
      testHost(bundle, const AnimatedMorphIcon(icon: testQuadraticIcon)),
    );
    await tester.pumpWidget(
      testHost(
        bundle,
        AnimatedMorphIcon(
          icon: _missing,
          onFallback: (_) => throw StateError('observer failed'),
          onEnd: () => ended++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isStateError);
    expect(find.byIcon(_missing), findsOneWidget);
    expect(ended, 1);
  });

  testWidgets('malformed fonts reach callback instead of debug reporting', (
    tester,
  ) async {
    final bundle = TestAssetBundle.fonts(
      manifest: {
        testFontFamily: ['broken.ttf'],
      },
      assets: {'broken.ttf': Uint8List(4)},
    );
    final failures = <MorphFallbackDetails>[];
    await tester.pumpWidget(
      testHost(
        bundle,
        MorphIcon(
          from: testQuadraticIcon,
          to: testCompositeIcon,
          progress: const AlwaysStoppedAnimation(1),
          onFallback: failures.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(failures, hasLength(1));
    expect(failures.single.error.toString(), contains('bundled font'));
    expect(tester.takeException(), isNull);
  });
}
