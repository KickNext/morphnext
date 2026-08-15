import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphnext/src/geometry/morph_plan.dart';
import 'package:morphnext/src/geometry/resample.dart';
import 'package:morphnext/src/geometry/shape.dart';
import 'package:morphnext/src/rendering/morph_painter.dart';

void main() {
  test('endpoints and adjacent frames share one polygon raster', () async {
    final plan = buildMorphPlan(
      sampleContours(<CubicContour>[_square()], pointCount: 4),
      sampleContours(<CubicContour>[_circle()], pointCount: 4),
    );
    const size = Size.square(128);
    const color = Color(0xff123456);

    for (final progress in const <double>[0, 0.000001, 0.999999, 1]) {
      final actual = await _rasterize((canvas) {
        MorphPainter(
          plan: plan,
          progress: AlwaysStoppedAnimation<double>(progress),
          color: color,
        ).paint(canvas, size);
      });
      final expected = await _rasterize((canvas) {
        final output = plan.allocateOutput();
        plan.interpolate(progress, output);
        final path = Path()..fillType = PathFillType.nonZero;
        for (final points in output) {
          path.moveTo(points[0] * size.width, points[1] * size.height);
          for (var index = 2; index < points.length; index += 2) {
            path.lineTo(
              points[index] * size.width,
              points[index + 1] * size.height,
            );
          }
          path.close();
        }
        canvas.drawPath(path, Paint()..color = color);
      });

      expect(actual, orderedEquals(expected), reason: 'progress $progress');
    }
  });

  test('endpoint pixels remain unchanged without a progress update', () async {
    final plan = buildMorphPlan(
      sampleContours(<CubicContour>[_square()], pointCount: 16),
      sampleContours(<CubicContour>[_circle()], pointCount: 16),
    );
    const size = Size.square(128);
    const color = Color(0xff123456);
    final painter = MorphPainter(
      plan: plan,
      progress: const AlwaysStoppedAnimation<double>(1),
      color: color,
    );
    final first = await _rasterize((canvas) => painter.paint(canvas, size));
    final second = await _rasterize((canvas) => painter.paint(canvas, size));

    expect(first, orderedEquals(second));
  });

  test('shadows and blend mode are painted by the vector renderer', () async {
    final plan = buildMorphPlan(
      sampleContours(<CubicContour>[_square()], pointCount: 4),
      sampleContours(<CubicContour>[_circle()], pointCount: 4),
    );
    const size = Size.square(128);
    const color = Color(0xff90caf9);
    const shadow = Shadow(
      color: Color(0x99000000),
      offset: Offset(8, 5),
      blurRadius: 3,
    );
    final actual = await _rasterize((canvas) {
      canvas.drawColor(const Color(0xff102030), BlendMode.src);
      MorphPainter(
        plan: plan,
        progress: const AlwaysStoppedAnimation<double>(0.5),
        color: color,
        shadows: const <Shadow>[shadow],
        blendMode: BlendMode.screen,
      ).paint(canvas, size);
    });
    final withoutProperties = await _rasterize((canvas) {
      canvas.drawColor(const Color(0xff102030), BlendMode.src);
      MorphPainter(
        plan: plan,
        progress: const AlwaysStoppedAnimation<double>(0.5),
        color: color,
      ).paint(canvas, size);
    });

    expect(actual, isNot(orderedEquals(withoutProperties)));
  });
}

Future<Uint8List> _rasterize(void Function(Canvas canvas) paint) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  final picture = recorder.endRecording();
  final image = await picture.toImage(128, 128);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  picture.dispose();
  image.dispose();
  return data!.buffer.asUint8List();
}

CubicContour _square() {
  final builder = CubicContourBuilder()
    ..moveTo(0.2, 0.2)
    ..lineTo(0.8, 0.2)
    ..lineTo(0.8, 0.8)
    ..lineTo(0.2, 0.8);
  return builder.close();
}

CubicContour _circle() {
  const radius = 0.4;
  const control = radius * 0.5522847498307936;
  final builder = CubicContourBuilder()..moveTo(0.5 + radius, 0.5);
  builder.cubicTo(0.5 + radius, 0.5 + control, 0.5 + control, 0.9, 0.5, 0.9);
  builder.cubicTo(0.5 - control, 0.9, 0.1, 0.5 + control, 0.1, 0.5);
  builder.cubicTo(0.1, 0.5 - control, 0.5 - control, 0.1, 0.5, 0.1);
  builder.cubicTo(0.5 + control, 0.1, 0.9, 0.5 - control, 0.9, 0.5);
  return builder.close();
}
