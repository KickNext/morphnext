// Manual A/B capture. Run the identical file against each revision:
// flutter test tool/visual_ab_test.dart --dart-define=VISUAL_OUTPUT=<directory>
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphnext/morphnext.dart';
import 'package:morphnext/src/morph_repository.dart';
import 'package:morphnext/src/rendering/morph_painter.dart';

import '../test/support/test_asset_bundle.dart';
import '../test/support/test_font_builder.dart';
import '../test/support/test_icons.dart';

const _output = String.fromEnvironment('VISUAL_OUTPUT');
const _boundary = ValueKey('capture');
const _cell = 128.0;
const _progress = [0.0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875, 1.0];

void main() {
  final fixtures = fixtureBundle();
  final variable = TestAssetBundle.fonts(
    manifest: {
      testFontFamily: ['variable.ttf'],
    },
    assets: {'variable.ttf': TestFontBuilder.variableTrueType()},
  );
  final cases = <_Case>[
    _Case('menu-close', Icons.menu, Icons.close, rootBundle),
    _Case('heart-hole', Icons.favorite_border, Icons.favorite, rootBundle),
    _Case('play-pause', Icons.play_arrow, Icons.pause, rootBundle),
    _Case('settings-tune', Icons.settings, Icons.tune, rootBundle),
    _Case('apps-dialpad', Icons.apps, Icons.dialpad, rootBundle),
    _Case('drag-more', Icons.drag_indicator, Icons.more_horiz, rootBundle),
    _Case('directional', Icons.arrow_back, Icons.arrow_forward, rootBundle),
    _Case('visibility', Icons.visibility, Icons.visibility_off, rootBundle),
    _Case(
      'fixture-holes',
      testSquareWithHoleIcon,
      testDiamondWithHoleIcon,
      fixtures,
    ),
    _Case('cff-truetype', testCffIcon, testQuadraticIcon, fixtures),
    _Case('composite', testCompositeIcon, testCompressedIcon, fixtures),
    _Case(
      'variable-weight',
      testQuadraticIcon,
      testCompositeIcon,
      variable,
      weight: 650,
    ),
  ];

  setUpAll(() async {
    if (_output.isEmpty) throw ArgumentError('Set VISUAL_OUTPUT');
    Directory(_output).createSync(recursive: true);
    await loadTestIconFonts();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  testWidgets('controlled frames and interrupted springs', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final files = <String>[];
    final geometry = <String, Object>{};
    for (final direction in TextDirection.values) {
      for (final entry in cases) {
        final plan = await tester.runAsync(
          () => MorphRepository.forBundle(entry.bundle)
              .planFor(entry.from, entry.to, direction, (
                fill: 0.0,
                weight: entry.weight ?? 400.0,
                grade: 0.0,
                opticalSize: 48.0,
                fontWeight: null,
              )),
        );
        geometry['${entry.name}-${direction.name}'] = plan!.items.length;
      }
    }

    for (final size in [24.0, 48.0, 96.0]) {
      for (final dpr in [1.0, 2.0]) {
        for (final direction in TextDirection.values) {
          for (final dark in [false, true]) {
            final name =
                '${size.toInt()}-${dpr.toInt()}-${direction.name}-${dark ? 'dark' : 'light'}';
            final extent = Size(_cell * _progress.length, _cell * cases.length);
            tester.view.devicePixelRatio = dpr;
            tester.view.physicalSize = extent * dpr;
            await tester.pumpWidget(
              _host(
                direction,
                dark,
                dpr,
                Column(
                  children: [
                    for (final entry in cases)
                      Row(
                        children: [
                          for (final progress in _progress)
                            _tile(
                              entry,
                              MorphIcon(
                                from: entry.from,
                                to: entry.to,
                                size: size,
                                weight: entry.weight,
                                progress: AlwaysStoppedAnimation(progress),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              find.byType(CustomPaint),
              findsNWidgets(cases.length * _progress.length),
            );
            await _capture(tester, 'controlled-$name.png');
            files.add('controlled-$name.png');
          }
        }
      }
    }

    for (final dpr in [1.0, 2.0]) {
      for (final direction in TextDirection.values) {
        final name = '${dpr.toInt()}-${direction.name}';
        tester.view.devicePixelRatio = dpr;
        tester.view.physicalSize = Size(_cell * cases.length, _cell) * dpr;
        await tester.pumpWidget(const SizedBox());
        Future<void> target(bool to) async {
          await tester.pumpWidget(
            _host(
              direction,
              false,
              dpr,
              Row(
                children: [
                  for (final entry in cases)
                    _tile(
                      entry,
                      AnimatedMorphIcon(
                        key: ValueKey(entry.name),
                        icon: to ? entry.to : entry.from,
                        size: 80,
                        weight: entry.weight,
                      ),
                    ),
                ],
              ),
            ),
          );
          // Flush preparation futures without advancing the animation clock.
          for (var i = 0; i < 20; i++) {
            await tester.pump();
          }
        }

        Future<void> capture(String phase) async {
          final file = 'spring-$name-$phase.png';
          await _capture(tester, file);
          files.add(file);
        }

        await target(false);
        await capture('00-initial');
        await target(true);
        expect(find.byType(CustomPaint), findsNWidgets(cases.length));
        await capture('01-start');
        await tester.pump(const Duration(milliseconds: 16));
        await capture('02-16ms');
        await tester.pump(const Duration(milliseconds: 54));
        await capture('03-before-retarget');
        await target(false);
        await capture('04-after-retarget');
        await tester.pump(const Duration(milliseconds: 16));
        await capture('05-retarget-16ms');
        await tester.pump(const Duration(milliseconds: 24));
        await capture('06-before-second-retarget');
        await target(true);
        await capture('07-after-second-retarget');
        for (var frame = 0; frame < 12; frame++) {
          await tester.pump(const Duration(milliseconds: 32));
          await capture('08-tail-${frame.toString().padLeft(2, '0')}');
        }
        await tester.pumpAndSettle();
        await capture('09-settled');
        for (final widget in tester.widgetList<CustomPaint>(
          find.byType(CustomPaint),
        )) {
          expect((widget.painter! as MorphPainter).progress.value, 1);
        }
      }
    }
    expect(tester.takeException(), isNull);
    File('$_output/manifest.json').writeAsStringSync(
      jsonEncode({
        'cases': [for (final entry in cases) entry.name],
        'progress': _progress,
        'contourPairs': geometry,
        'files': files,
      }),
    );
  }, timeout: const Timeout(Duration(minutes: 5)));
}

Widget _host(TextDirection direction, bool dark, double dpr, Widget child) =>
    MediaQuery(
      data: MediaQueryData(devicePixelRatio: dpr),
      child: Directionality(
        textDirection: direction,
        child: IconTheme(
          data: IconThemeData(
            color: dark ? const Color(0xffe2eaff) : const Color(0xff234785),
            shadows: dark
                ? const [
                    Shadow(
                      color: Color(0x66000000),
                      blurRadius: 2,
                      offset: Offset(1, 2),
                    ),
                  ]
                : null,
          ),
          child: RepaintBoundary(
            key: _boundary,
            child: ColoredBox(
              color: dark ? const Color(0xff162032) : const Color(0xfff4f6fa),
              child: child,
            ),
          ),
        ),
      ),
    );

Widget _tile(_Case entry, Widget child) => SizedBox.square(
  dimension: _cell,
  child: DefaultAssetBundle(
    bundle: entry.bundle,
    child: Center(child: child),
  ),
);

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundary),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(
      pixelRatio: tester.view.devicePixelRatio,
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File('$_output/$name').writeAsBytesSync(
      data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  });
}

class _Case {
  const _Case(this.name, this.from, this.to, this.bundle, {this.weight});
  final String name;
  final IconData from;
  final IconData to;
  final AssetBundle bundle;
  final double? weight;
}
