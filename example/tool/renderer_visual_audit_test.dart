// Manual exhaustive audit. Run from example/ with:
// flutter test tool/renderer_visual_audit_test.dart
//
// Keeping this outside test/ prevents the default test suite and CI from
// processing the complete icon catalog.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphnext/src/geometry/morph_plan.dart';
import 'package:morphnext/src/morph_repository.dart';
import 'package:morphnext/src/rendering/morph_painter.dart';
import 'package:morphnext_example/icon_catalog.dart';

const _panelSize = 128;
const _iconSize = 80.0;
const _captureScale = 2;
const _columnCount = 4;
const _rowCount = 8;
const _batchSize = _columnCount * _rowCount;
const _canvasWidth = 3 * _panelSize * _columnCount;
const _canvasHeight = _panelSize * _rowCount;
const _canvasPixelWidth = _captureScale * _canvasWidth;
const _panelPixelSize = _captureScale * _panelSize;
const _minimumExactMotionSimilarity = 0.99;
const _minimumNativeExactSimilarity = 0.90;
const _inkThreshold = 8;
const _painterProgressMicros = int.fromEnvironment(
  'MORPHNEXT_AUDIT_PROGRESS_MICROS',
  defaultValue: 999999,
);
const _painterProgress = _painterProgressMicros / 1000000;
const _caseLimit = int.fromEnvironment('MORPHNEXT_AUDIT_LIMIT');
const _reportOnly = bool.fromEnvironment('MORPHNEXT_AUDIT_REPORT_ONLY');
const _caseQuery = String.fromEnvironment('MORPHNEXT_AUDIT_QUERY');
const _caseFamily = String.fromEnvironment('MORPHNEXT_AUDIT_FAMILY');
const _endpoint = String.fromEnvironment(
  'MORPHNEXT_AUDIT_ENDPOINT',
  defaultValue: 'target',
);
const _sourceEndpoint = _endpoint == 'source';

void main() {
  setUpAll(_loadIconFonts);

  testWidgets(
    'all MorphPainter endpoint glyphs visually match native contours',
    (tester) async {
      expect(_endpoint, anyOf('source', 'target'));
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(
        _canvasWidth * 1.0,
        _canvasHeight * 1.0,
      );
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final allIdentities = _auditIdentities();
      final identities = allIdentities
          .where((identity) {
            final matchesQuery =
                _caseQuery.isEmpty ||
                identity.entry.name.toLowerCase().contains(
                  _caseQuery.toLowerCase(),
                );
            final matchesFamily =
                _caseFamily.isEmpty ||
                identity.entry.family.name.toLowerCase() ==
                    _caseFamily.toLowerCase();
            return matchesQuery && matchesFamily;
          })
          .toList(growable: false);
      final selected = _caseLimit > 0
          ? identities.take(_caseLimit).toList(growable: false)
          : identities;
      final repository = MorphRepository.forBundle(rootBundle);
      final results = <_AuditResult>[];
      final artifactDirectory = Directory('build/renderer_visual_audit/diffs')
        ..createSync(recursive: true);

      for (var start = 0; start < selected.length; start += _batchSize) {
        final end = math.min(start + _batchSize, selected.length);
        final batchIdentities = selected.sublist(start, end);
        final cases = (await tester.runAsync<List<_AuditCase>>(() async {
          final batch = <_AuditCase>[];
          for (final identity in batchIdentities) {
            final anchor = _sourceIcon(identity.entry);
            final plan = await repository.planFor(
              _sourceEndpoint ? identity.entry.icon : anchor,
              _sourceEndpoint ? anchor : identity.entry.icon,
              identity.direction,
            );
            batch.add(_AuditCase(identity: identity, plan: plan));
          }
          return batch;
        }))!;

        const boundaryKey = ValueKey<String>('visual-audit-batch');
        await tester.pumpWidget(_AuditCanvas(key: boundaryKey, cases: cases));
        await tester.pump();

        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(boundaryKey),
        );
        final rgba = (await tester.runAsync<Uint8List>(() async {
          final image = await boundary.toImage(
            pixelRatio: _captureScale.toDouble(),
          );
          final data = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          image.dispose();
          return Uint8List.fromList(
            data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          );
        }))!;

        for (var index = 0; index < cases.length; index++) {
          final identity = cases[index].identity;
          final nativeToExact = _comparePanels(
            rgba,
            index,
            firstPanel: 0,
            secondPanel: 1,
          );
          final exactToMotion = _comparePanels(
            rgba,
            index,
            firstPanel: 1,
            secondPanel: 2,
          );
          final nativeToMotion = _comparePanels(
            rgba,
            index,
            firstPanel: 0,
            secondPanel: 2,
          );
          final artifactName = _artifactName(identity);
          final result = _AuditResult(
            identity: identity,
            nativeToExact: nativeToExact,
            exactToMotion: exactToMotion,
            nativeToMotion: nativeToMotion,
            artifactName: artifactName,
          );
          results.add(result);
          if (_caseQuery.isNotEmpty || result.hasUnexpectedDiff) {
            await tester.runAsync<void>(
              () => _writeDiffPng(
                rgba,
                index,
                File('${artifactDirectory.path}/$artifactName'),
              ),
            );
          }
        }
      }

      results.sort(
        (left, right) => left.sortSimilarity.compareTo(right.sortSimilarity),
      );
      final unexpected = <_AuditResult>[
        for (final result in results)
          if (result.hasUnexpectedDiff) result,
      ];
      await tester.runAsync<void>(
        () => _writeReports(results: results, unexpected: unexpected),
      );

      final summary = <String, Object>{
        'cases': results.length,
        'glyphs': selected
            .where((item) => item.direction == TextDirection.ltr)
            .length,
        'rtlCases': selected
            .where((item) => item.direction == TextDirection.rtl)
            .length,
        'unexpectedDiffs': unexpected.length,
        'endpoint': _endpoint,
        'report': 'build/renderer_visual_audit/index.html',
      };
      // A single machine-readable line keeps CI logs compact.
      // ignore: avoid_print
      print(jsonEncode(summary));

      if (_reportOnly) return;
      expect(
        unexpected,
        isEmpty,
        reason: _failureReason('Unexpected visual differences', unexpected),
      );
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
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

List<_AuditIdentity> _auditIdentities() {
  final identities = <_AuditIdentity>[];
  for (final entry in iconCatalog) {
    identities.add(_AuditIdentity(entry: entry, direction: TextDirection.ltr));
    if (entry.icon.matchTextDirection) {
      identities.add(
        _AuditIdentity(entry: entry, direction: TextDirection.rtl),
      );
    }
  }
  return identities;
}

final class _AuditIdentity {
  const _AuditIdentity({required this.entry, required this.direction});

  final IconCatalogEntry entry;
  final TextDirection direction;
}

final class _AuditCase {
  const _AuditCase({required this.identity, required this.plan});

  final _AuditIdentity identity;
  final MorphPlan plan;
}

final class _AuditCanvas extends StatelessWidget {
  const _AuditCanvas({required this.cases, super.key});

  final List<_AuditCase> cases;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: RepaintBoundary(
      child: ColoredBox(
        color: const Color(0xffffffff),
        child: SizedBox(
          width: _canvasWidth.toDouble(),
          height: _canvasHeight.toDouble(),
          child: Column(
            children: <Widget>[
              for (var row = 0; row < _rowCount; row++)
                SizedBox(
                  height: _panelSize.toDouble(),
                  child: Row(
                    children: <Widget>[
                      for (var column = 0; column < _columnCount; column++)
                        _auditCell(row * _columnCount + column),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _auditCell(int index) {
    if (index >= cases.length) {
      return const SizedBox(width: 3.0 * _panelSize, height: 1.0 * _panelSize);
    }
    final auditCase = cases[index];
    return SizedBox(
      width: 3 * _panelSize.toDouble(),
      height: _panelSize.toDouble(),
      child: Row(
        textDirection: TextDirection.ltr,
        children: <Widget>[
          _panel(
            Directionality(
              textDirection: auditCase.identity.direction,
              child: Icon(
                auditCase.identity.entry.icon,
                size: _iconSize,
                color: const Color(0xff202124),
                applyTextScaling: false,
              ),
            ),
          ),
          _panel(
            CustomPaint(
              painter: MorphPainter(
                plan: auditCase.plan,
                progress: const AlwaysStoppedAnimation<double>(
                  _sourceEndpoint ? 0 : 1,
                ),
                color: const Color(0xff202124),
              ),
            ),
          ),
          _panel(
            CustomPaint(
              painter: MorphPainter(
                plan: auditCase.plan,
                progress: const AlwaysStoppedAnimation<double>(
                  _sourceEndpoint ? 1 - _painterProgress : _painterProgress,
                ),
                color: const Color(0xff202124),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel(Widget child) => ClipRect(
    child: SizedBox.square(
      dimension: _panelSize.toDouble(),
      child: Center(
        child: SizedBox.square(dimension: _iconSize, child: child),
      ),
    ),
  );
}

IconData _sourceIcon(IconCatalogEntry entry) {
  final primary = entry.family == IconCatalogFamily.cupertino
      ? CupertinoIcons.circle
      : Icons.circle;
  if (entry.icon != primary) return primary;
  return entry.family == IconCatalogFamily.cupertino
      ? CupertinoIcons.square
      : Icons.square;
}

final class _DiffMetrics {
  const _DiffMetrics({
    required this.similarity,
    required this.maskSimilarity,
    required this.normalizedDifference,
    required this.firstInk,
    required this.secondInk,
    required this.centroidDx,
    required this.leftEdgeDx,
    required this.rightEdgeDx,
  });

  final double similarity;
  final double maskSimilarity;
  final double normalizedDifference;
  final int firstInk;
  final int secondInk;
  final double centroidDx;
  final double leftEdgeDx;
  final double rightEdgeDx;

  Map<String, Object> toJson() => <String, Object>{
    'softIou': similarity,
    'strictMaskIou': maskSimilarity,
    'normalizedDifference': normalizedDifference,
    'firstInk': firstInk,
    'secondInk': secondInk,
    'centroidDx': centroidDx,
    'leftEdgeDx': leftEdgeDx,
    'rightEdgeDx': rightEdgeDx,
  };
}

final class _AuditResult {
  const _AuditResult({
    required this.identity,
    required this.nativeToExact,
    required this.exactToMotion,
    required this.nativeToMotion,
    required this.artifactName,
  });

  final _AuditIdentity identity;
  final _DiffMetrics nativeToExact;
  final _DiffMetrics exactToMotion;
  final _DiffMetrics nativeToMotion;
  final String artifactName;

  bool get hasUnexpectedDiff =>
      exactToMotion.maskSimilarity < _minimumExactMotionSimilarity ||
      nativeToExact.maskSimilarity < _minimumNativeExactSimilarity;

  double get sortSimilarity =>
      math.min(nativeToExact.maskSimilarity, exactToMotion.maskSimilarity);

  Map<String, Object> toJson() => <String, Object>{
    'name': identity.entry.name,
    'family': identity.entry.family.name,
    'codePoint':
        '0x${identity.entry.icon.codePoint.toRadixString(16).toUpperCase()}',
    'direction': identity.direction.name,
    'nativeToExact': nativeToExact.toJson(),
    'exactToMotion': exactToMotion.toJson(),
    'nativeToMotion': nativeToMotion.toJson(),
    'artifact': 'diffs/$artifactName',
  };
}

_DiffMetrics _comparePanels(
  Uint8List rgba,
  int index, {
  required int firstPanel,
  required int secondPanel,
}) {
  final column = index % _columnCount;
  final row = index ~/ _columnCount;
  final caseX = column * 3 * _panelPixelSize;
  final firstX = caseX + firstPanel * _panelPixelSize;
  final secondX = caseX + secondPanel * _panelPixelSize;
  final y = row * _panelPixelSize;
  var intersection = 0;
  var union = 0;
  var difference = 0;
  var firstInk = 0;
  var secondInk = 0;
  var maskIntersection = 0;
  var maskUnion = 0;
  var firstMomentX = 0.0;
  var secondMomentX = 0.0;
  var firstMinX = _panelPixelSize;
  var firstMaxX = -1;
  var secondMinX = _panelPixelSize;
  var secondMaxX = -1;
  for (var localY = 0; localY < _panelPixelSize; localY++) {
    for (var localX = 0; localX < _panelPixelSize; localX++) {
      final first = _inkAt(rgba, firstX + localX, y + localY);
      final second = _inkAt(rgba, secondX + localX, y + localY);
      final firstMask = first >= _inkThreshold;
      final secondMask = second >= _inkThreshold;
      if (firstMask && secondMask) maskIntersection++;
      if (firstMask || secondMask) maskUnion++;
      intersection += math.min(first, second);
      union += math.max(first, second);
      difference += (first - second).abs();
      firstInk += first;
      secondInk += second;
      firstMomentX += localX * first;
      secondMomentX += localX * second;
      if (firstMask) {
        firstMinX = math.min(firstMinX, localX);
        firstMaxX = math.max(firstMaxX, localX);
      }
      if (secondMask) {
        secondMinX = math.min(secondMinX, localX);
        secondMaxX = math.max(secondMaxX, localX);
      }
    }
  }
  final inkScale = math.max(firstInk, secondInk);
  final firstCentroidX = firstInk == 0 ? 0 : firstMomentX / firstInk;
  final secondCentroidX = secondInk == 0 ? 0 : secondMomentX / secondInk;
  return _DiffMetrics(
    similarity: union == 0 ? 1 : intersection / union,
    maskSimilarity: maskUnion == 0 ? 1 : maskIntersection / maskUnion,
    normalizedDifference: inkScale == 0 ? 0 : difference / inkScale,
    firstInk: firstInk,
    secondInk: secondInk,
    centroidDx: (secondCentroidX - firstCentroidX) / _captureScale,
    leftEdgeDx: (secondMinX == _panelPixelSize || firstMinX == _panelPixelSize)
        ? 0
        : (secondMinX - firstMinX) / _captureScale,
    rightEdgeDx: (secondMaxX < 0 || firstMaxX < 0)
        ? 0
        : (secondMaxX - firstMaxX) / _captureScale,
  );
}

int _inkAt(Uint8List rgba, int x, int y) =>
    255 - rgba[4 * (y * _canvasPixelWidth + x)];

String _artifactName(_AuditIdentity identity) =>
    '${identity.entry.family.name}_${identity.entry.name}_'
    '${identity.direction.name}_$_endpoint.png';

Future<void> _writeDiffPng(Uint8List source, int index, File output) async {
  final width = 5 * _panelPixelSize;
  final bytes = Uint8List(width * _panelPixelSize * 4);
  final column = index % _columnCount;
  final row = index ~/ _columnCount;
  final nativeX = column * 3 * _panelPixelSize;
  final exactX = nativeX + _panelPixelSize;
  final motionX = exactX + _panelPixelSize;
  final sourceY = row * _panelPixelSize;
  for (var y = 0; y < _panelPixelSize; y++) {
    for (var x = 0; x < _panelPixelSize; x++) {
      final nativeSource =
          4 * ((sourceY + y) * _canvasPixelWidth + nativeX + x);
      final exactSource = 4 * ((sourceY + y) * _canvasPixelWidth + exactX + x);
      final motionSource =
          4 * ((sourceY + y) * _canvasPixelWidth + motionX + x);
      final nativeTarget = 4 * (y * width + x);
      final exactTarget = 4 * (y * width + _panelPixelSize + x);
      final motionTarget = 4 * (y * width + 2 * _panelPixelSize + x);
      bytes.setRange(nativeTarget, nativeTarget + 4, source, nativeSource);
      bytes.setRange(exactTarget, exactTarget + 4, source, exactSource);
      bytes.setRange(motionTarget, motionTarget + 4, source, motionSource);
      _writeHeatmapPixel(
        bytes,
        4 * (y * width + 3 * _panelPixelSize + x),
        source,
        nativeSource,
        motionSource,
      );
      _writeHeatmapPixel(
        bytes,
        4 * (y * width + 4 * _panelPixelSize + x),
        source,
        exactSource,
        motionSource,
      );
    }
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: width,
    height: _panelPixelSize,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await descriptor.instantiateCodec();
  final frame = await codec.getNextFrame();
  final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
  await output.writeAsBytes(png!.buffer.asUint8List(), flush: true);
  frame.image.dispose();
  codec.dispose();
  descriptor.dispose();
  buffer.dispose();
}

void _writeHeatmapPixel(
  Uint8List target,
  int targetIndex,
  Uint8List source,
  int firstIndex,
  int secondIndex,
) {
  final firstInk = 255 - source[firstIndex];
  final secondInk = 255 - source[secondIndex];
  final overlap = math.min(firstInk, secondInk);
  final firstOnly = math.max(firstInk - secondInk, 0);
  final secondOnly = math.max(secondInk - firstInk, 0);
  target[targetIndex] = (255 - overlap - secondOnly).clamp(0, 255);
  target[targetIndex + 1] = (255 - overlap - firstOnly - secondOnly).clamp(
    0,
    255,
  );
  target[targetIndex + 2] = (255 - overlap - firstOnly).clamp(0, 255);
  target[targetIndex + 3] = 255;
}

Future<void> _writeReports({
  required List<_AuditResult> results,
  required List<_AuditResult> unexpected,
}) async {
  final directory = Directory('build/renderer_visual_audit')
    ..createSync(recursive: true);
  final unexpectedMotion = unexpected
      .where(
        (result) =>
            result.exactToMotion.maskSimilarity < _minimumExactMotionSimilarity,
      )
      .toList(growable: false);
  final nativeRasterDifferences = unexpected
      .where(
        (result) =>
            result.nativeToExact.maskSimilarity < _minimumNativeExactSimilarity,
      )
      .toList(growable: false);
  final report = <String, Object>{
    'captureScale': _captureScale,
    'endpoint': _endpoint,
    'minimumNativeExactStrictMaskIou': _minimumNativeExactSimilarity,
    'minimumExactMotionStrictMaskIou': _minimumExactMotionSimilarity,
    'minimumObservedNativeExactStrictMaskIou': results.fold<double>(
      1,
      (minimum, result) =>
          math.min(minimum, result.nativeToExact.maskSimilarity),
    ),
    'minimumObservedExactMotionStrictMaskIou': results.fold<double>(
      1,
      (minimum, result) =>
          math.min(minimum, result.exactToMotion.maskSimilarity),
    ),
    'caseCount': results.length,
    'unexpectedDiffCount': unexpected.length,
    'unexpectedMotionDiffCount': unexpectedMotion.length,
    'nativeRasterDifferenceCount': nativeRasterDifferences.length,
    'unexpectedDiffs': unexpected.map((result) => result.toJson()).toList(),
    'worstCases': results.take(100).map((result) => result.toJson()).toList(),
    'worstExactMotionCases':
        (results.toList()..sort(
              (left, right) => left.exactToMotion.maskSimilarity.compareTo(
                right.exactToMotion.maskSimilarity,
              ),
            ))
            .take(100)
            .map((result) => result.toJson())
            .toList(),
    'largestHorizontalShifts':
        (results.toList()..sort(
              (left, right) => right.nativeToMotion.centroidDx.abs().compareTo(
                left.nativeToMotion.centroidDx.abs(),
              ),
            ))
            .take(100)
            .map((result) => result.toJson())
            .toList(),
  };
  await File('${directory.path}/report.json').writeAsString(
    const JsonEncoder.withIndent('  ').convert(report),
    flush: true,
  );
  final visible =
      <_AuditResult>{
        ...unexpected,
        if (_caseQuery.isNotEmpty) ...results,
      }.toList()..sort(
        (left, right) => left.sortSimilarity.compareTo(right.sortSimilarity),
      );
  final rows = StringBuffer();
  for (final result in visible) {
    final status =
        result.exactToMotion.maskSimilarity < _minimumExactMotionSimilarity
        ? 'Unexpected MorphPainter motion diff'
        : 'Native font/path rasterization difference';
    rows.writeln('''
      <article>
        <div>
          <h2>${_html(result.identity.entry.name)}</h2>
          <p>$status · ${result.identity.direction.name} ·
             native→exact ${result.nativeToExact.maskSimilarity.toStringAsFixed(6)} ·
             exact→motion ${result.exactToMotion.maskSimilarity.toStringAsFixed(6)} ·
             native→motion ${result.nativeToMotion.maskSimilarity.toStringAsFixed(6)}</p>
        </div>
        <img src="diffs/${_html(result.artifactName)}"
             alt="Native, MorphPainter, and heatmap for ${_html(result.identity.entry.name)}">
      </article>
    ''');
  }
  await File('${directory.path}/index.html').writeAsString('''
<!doctype html>
<html lang="en">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>morphnext renderer visual audit</title>
<style>
  :root { font-family: system-ui, sans-serif; color-scheme: light dark; }
  body { max-width: 1040px; margin: auto; padding: 24px; }
  header { margin-bottom: 24px; }
  article { display: flex; gap: 24px; align-items: center; justify-content: space-between;
            padding: 16px 0; border-top: 1px solid #8886; }
  h2 { margin: 0 0 6px; font-size: 18px; }
  p { margin: 0; color: #777; }
  img { width: ${5 * _panelSize}px; max-width: 100%; image-rendering: auto; background: white; }
  code { background: #8882; padding: 2px 5px; border-radius: 4px; }
  @media (max-width: 720px) { article { align-items: start; flex-direction: column; } }
</style>
<body>
  <header>
    <h1>morphnext renderer visual audit</h1>
    <p>${results.length} render cases at $_captureScale×. Panels are
       <code>Flutter native</code>, <code>exact path</code>,
       <code>adjacent motion frame</code>, <code>native↔motion diff</code>, and
       <code>exact↔motion diff</code>.</p>
    <p>${unexpectedMotion.length} unexpected motion differences;
       ${nativeRasterDifferences.length} native font/path rasterization differences.</p>
  </header>
  $rows
</body>
</html>
''', flush: true);
}

String _html(String value) => const HtmlEscape().convert(value);

String _failureReason(String title, List<_AuditResult> results) {
  final buffer = StringBuffer(
    '$title. Full report: '
    'build/renderer_visual_audit/index.html',
  );
  for (final result in results.take(20)) {
    buffer.write(
      '\n${result.identity.entry.name} (${result.identity.direction.name}): '
      '${result.nativeToExact.maskSimilarity.toStringAsFixed(6)} native→exact · '
      '${result.exactToMotion.maskSimilarity.toStringAsFixed(6)} exact→motion',
    );
  }
  if (results.length > 20) {
    buffer.write('\n…and ${results.length - 20} more');
  }
  return buffer.toString();
}
