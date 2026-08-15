// Manual design-review aid. Run from example/ with:
// flutter test tool/site_design_capture_test.dart
//
// Writes build/site_design/*.png — the landing and playground pages in both
// themes — so a restyle can be reviewed as pixels without launching the app.
// Reuses the film tooling's font trick: icon fonts come from the bundle and
// display faces from the google_fonts cache of the last real run.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:morphnext_example/main.dart';

void main() {
  setUpAll(() async {
    await _loadIconFonts();
    await _loadDisplayFonts();
  });

  for (final (route, name, height) in <(String, String, double)>[
    ('/', 'random', 3400),
    ('/playground', 'playground', 1500),
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets('captures $name (${brightness.name})', (tester) async {
        tester.view.physicalSize = Size(1280, height);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey<String>('site-capture'),
            child: MorphnextExampleApp(
              initialLocation: route,
              initialBrightnessOverride: brightness,
              loadLiveMetadata: false,
            ),
          ),
        );
        // Real time between pumps lets the async morph plans resolve, so the
        // icons render as glyphs instead of empty slots.
        for (var i = 0; i < 8; i++) {
          await tester.runAsync<void>(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump(const Duration(milliseconds: 120));
        }
        expect(tester.takeException(), isNull);

        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey<String>('site-capture')),
        );
        final png = (await tester.runAsync<Uint8List>(() async {
          final image = await boundary.toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          return data!.buffer.asUint8List();
        }))!;
        final file = File('build/site_design/${name}_${brightness.name}.png');
        await tester.runAsync<void>(() async {
          file.parent.createSync(recursive: true);
          await file.writeAsBytes(png, flush: true);
        });
        // ignore: avoid_print
        print('wrote ${file.path}');
      });
    }
  }
}

Future<void> _loadIconFonts() async {
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json', cache: false))
          as List<Object?>;
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

const _fontCache = String.fromEnvironment('MORPHNEXT_FONT_CACHE');

Future<void> _loadDisplayFonts() async {
  GoogleFonts.config.allowRuntimeFetching = false;
  final directory = Directory(
    _fontCache.isNotEmpty
        ? _fontCache
        : '${Platform.environment['APPDATA']}/com.example/morphnext',
  );
  if (!directory.existsSync()) {
    // ignore: avoid_print
    print('no font cache at ${directory.path}; using the test font');
    return;
  }
  final cached = directory
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.ttf'))
      .toList(growable: false);

  final wanted = <(String, TextStyle)>[
    ('InstrumentSans', GoogleFonts.instrumentSans(fontWeight: FontWeight.w800)),
    ('InstrumentSans', GoogleFonts.instrumentSans(fontWeight: FontWeight.w600)),
    ('JetBrainsMono', GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w700)),
    ('JetBrainsMono', GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w600)),
  ];
  final loaded = <String>{};
  for (final (name, style) in wanted) {
    final family = style.fontFamily;
    if (family == null || !loaded.add(family)) continue;
    final target = (style.fontWeight ?? FontWeight.w400).value;
    File? best;
    var bestDistance = 1 << 30;
    for (final file in cached) {
      final parts = file.uri.pathSegments.last.split('_');
      if (parts.length < 2 || parts.first != name) continue;
      final weight = int.tryParse(parts[1]);
      if (weight == null) continue;
      final distance = (weight - target).abs();
      if (distance >= bestDistance) continue;
      bestDistance = distance;
      best = file;
    }
    if (best == null) continue;
    await (FontLoader(family)..addFont(
          Future<ByteData>.value(ByteData.sublistView(best.readAsBytesSync())),
        ))
        .load();
  }
  // ignore: avoid_print
  print('registered display faces: ${loaded.join(', ')}');
}
