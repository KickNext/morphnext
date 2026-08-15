import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphnext/morphnext.dart';
import 'package:morphnext/src/font/open_type_font.dart';
import 'package:morphnext/src/rendering/morph_painter.dart';
import 'package:morphnext_example/icon_catalog.dart';

late final Map<String, String> _fontAssets;

void main() {
  setUpAll(() async {
    final manifest = await _fontManifest();
    _fontAssets = <String, String>{};
    for (final rawFamily in manifest) {
      final family = rawFamily! as Map<String, Object?>;
      final firstFace = (family['fonts']! as List<Object?>).first!;
      _fontAssets[family['family']! as String] =
          (firstFace as Map<String, Object?>)['asset']! as String;
    }
    await _loadIconFonts(manifest);
  });

  testWidgets('representative font faces use native Icon metrics', (
    tester,
  ) async {
    final parsedFonts = <String, OpenTypeFont>{};
    for (final fontCase in _fontCases()) {
      for (final icon in <IconData>[fontCase.source, fontCase.target]) {
        final family = _manifestFamily(icon);
        final font = parsedFonts[family] ??= await _parseFont(family);
        final outline = font.glyphForCodePoint(icon.codePoint);
        for (final size in const <double>[24, 82, 128, 364]) {
          final painter = TextPainter(
            text: TextSpan(
              text: String.fromCharCode(icon.codePoint),
              style: TextStyle(
                inherit: false,
                fontSize: size,
                fontFamily: icon.fontFamily,
                package: icon.fontPackage,
                height: 1,
                leadingDistribution: TextLeadingDistribution.even,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: size);
          addTearDown(painter.dispose);

          final scale = size / font.metrics.unitsPerEm;
          final line = painter.computeLineMetrics().single;
          final expectedBaseline =
              (size -
                      (font.metrics.ascender - font.metrics.descender) *
                          scale) /
                  2 +
              font.metrics.ascender * scale;
          final nativeBaseline = (size - line.height) / 2 + line.baseline;
          final expectedLeft = outline.advanceWidth < font.metrics.unitsPerEm
              ? (size - outline.advanceWidth * scale) / 2
              : 0.0;
          final nativeLeft = (size - painter.width) / 2;

          expect(
            nativeBaseline,
            closeTo(expectedBaseline, 0.001),
            reason:
                '${fontCase.name} at $size px must use Icon vertical metrics',
          );
          expect(
            nativeLeft,
            closeTo(expectedLeft, 0.001),
            reason:
                '${fontCase.name} at $size px must use Icon horizontal metrics',
          );
        }
      }
    }
  });

  testWidgets('representative font faces stay inside the Icon pixel envelope', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 320);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final fontCase in _fontCases()) {
      for (final pair in <(IconData, IconData)>[
        (fontCase.source, fontCase.target),
        (fontCase.target, fontCase.source),
      ]) {
        for (final size in const <double>[24, 82, 128]) {
          await tester.pumpWidget(
            MaterialApp(
              key: UniqueKey(),
              home: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _Sample(
                      sampleKey: const ValueKey<String>('morph'),
                      child: MorphIcon(
                        from: pair.$1,
                        to: pair.$2,
                        progress: const AlwaysStoppedAnimation<double>(
                          0.999999,
                        ),
                        size: size,
                        color: const Color(0xff202124),
                      ),
                    ),
                    _Sample(
                      sampleKey: const ValueKey<String>('native'),
                      child: Icon(
                        pair.$2,
                        size: size,
                        color: const Color(0xff202124),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          await _waitForMorphPainter(tester);

          final morphMask = await _inkMask(
            tester,
            const ValueKey<String>('morph'),
          );
          final nativeMask = await _inkMask(
            tester,
            const ValueKey<String>('native'),
          );
          final morph = _centroid(morphMask, _sampleSize);
          final native = _centroid(nativeMask, _sampleSize);

          expect(
            (morph.$1 - native.$1).abs(),
            lessThan(0.75),
            reason:
                '${fontCase.name} at $size px left the Icon horizontal envelope',
          );
          expect(
            (morph.$2 - native.$2).abs(),
            lessThan(0.75),
            reason:
                '${fontCase.name} at $size px left the Icon vertical envelope',
          );
        }
      }
    }
  });
}

List<_FontCase> _fontCases() {
  IconData icon(String name, IconCatalogFamily family) => iconCatalog
      .singleWhere((entry) => entry.name == name && entry.family == family)
      .icon;

  return <_FontCase>[
    _FontCase(
      'Material',
      icon('menu', IconCatalogFamily.material),
      icon('abc', IconCatalogFamily.material),
    ),
    _FontCase(
      'Font Awesome Brands',
      icon('github', IconCatalogFamily.fontAwesome),
      icon('angrycreative', IconCatalogFamily.fontAwesome),
    ),
  ];
}

String _manifestFamily(IconData icon) => icon.fontPackage == null
    ? icon.fontFamily!
    : 'packages/${icon.fontPackage}/${icon.fontFamily}';

Future<OpenTypeFont> _parseFont(String family) async {
  final data = await rootBundle.load(_fontAssets[family]!);
  return OpenTypeFont.parse(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
}

Future<List<Object?>> _fontManifest() async =>
    jsonDecode(await rootBundle.loadString('FontManifest.json', cache: false))
        as List<Object?>;

Future<void> _loadIconFonts(List<Object?> manifest) async {
  final loads = <Future<void>>[];
  for (final rawFamily in manifest) {
    final family = rawFamily! as Map<String, Object?>;
    final loader = FontLoader(family['family']! as String);
    for (final rawFace in family['fonts']! as List<Object?>) {
      final face = rawFace! as Map<String, Object?>;
      loader.addFont(rootBundle.load(face['asset']! as String));
    }
    loads.add(loader.load());
  }
  await Future.wait<void>(loads);
}

const _sampleSize = 256;

final class _FontCase {
  const _FontCase(this.name, this.source, this.target);

  final String name;
  final IconData source;
  final IconData target;
}

final class _Sample extends StatelessWidget {
  const _Sample({required this.sampleKey, required this.child});

  final Key sampleKey;
  final Widget child;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    key: sampleKey,
    child: ColoredBox(
      color: const Color(0xffffffff),
      child: SizedBox.square(
        dimension: _sampleSize.toDouble(),
        child: Center(child: child),
      ),
    ),
  );
}

Future<void> _waitForMorphPainter(WidgetTester tester) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 1));
    if (tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .any((widget) => widget.painter is MorphPainter)) {
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
  }
  fail('MorphPainter did not become ready');
}

Future<Uint8List> _inkMask(WidgetTester tester, Key key) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  return (await tester.runAsync<Uint8List>(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    final rgba = data!.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    return Uint8List.fromList(<int>[
      for (var index = 0; index < rgba.length; index += 4) 255 - rgba[index],
    ]);
  }))!;
}

(double, double) _centroid(Uint8List mask, int width) {
  var ink = 0;
  var xMoment = 0;
  var yMoment = 0;
  for (var index = 0; index < mask.length; index++) {
    final value = mask[index];
    ink += value;
    xMoment += (index % width) * value;
    yMoment += (index ~/ width) * value;
  }
  return (xMoment / ink, yMoment / ink);
}
