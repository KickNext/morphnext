import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../geometry/morph_plan.dart';

double clampMorphProgress(double value, {bool allowOvershoot = false}) {
  if (value.isNaN) return 0;
  return value
      .clamp(allowOvershoot ? -0.25 : 0.0, allowOvershoot ? 1.25 : 1.0)
      .toDouble();
}

/// Paints an already prepared morph plan with one continuous vector raster.
final class MorphPainter extends CustomPainter {
  MorphPainter({
    required this.plan,
    required this.progress,
    required Color color,
    List<Shadow>? shadows,
    this.blendMode,
    this.allowOvershoot = false,
  }) : _color = color,
       _shadows = List<Shadow>.unmodifiable(shadows ?? const <Shadow>[]),
       _shadowPaints = <Paint>[
         for (final shadow in shadows ?? const <Shadow>[]) shadow.toPaint(),
       ],
       _output = plan.allocateOutput(),
       _paint = Paint()
         ..color = color
         ..blendMode = blendMode ?? BlendMode.srcOver,
       super(repaint: progress);

  final MorphPlan plan;
  final Animation<double> progress;
  final bool allowOvershoot;
  final BlendMode? blendMode;
  final Color _color;
  final List<Shadow> _shadows;
  final List<Paint> _shadowPaints;
  final List<Float64List> _output;
  final Path _path = Path()..fillType = PathFillType.nonZero;
  final Paint _paint;

  @visibleForTesting
  Color get color => _color;

  @visibleForTesting
  List<Float64List> get debugOutput => <Float64List>[
    for (final points in _output) Float64List.fromList(points),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = clampMorphProgress(
      progress.value,
      allowOvershoot: allowOvershoot,
    );
    plan.interpolate(t, _output);
    _path
      ..reset()
      ..fillType = PathFillType.nonZero;
    _addSampledOutline(size);
    for (var index = 0; index < _shadows.length; index++) {
      final shadow = _shadows[index];
      canvas.save();
      canvas.translate(shadow.offset.dx, shadow.offset.dy);
      canvas.drawPath(_path, _shadowPaints[index]);
      canvas.restore();
    }
    _paint.color = _color;
    canvas.drawPath(_path, _paint);
  }

  void _addSampledOutline(Size size) {
    for (final points in _output) {
      _path.moveTo(points[0] * size.width, points[1] * size.height);
      for (var index = 2; index < points.length; index += 2) {
        _path.lineTo(
          points[index] * size.width,
          points[index + 1] * size.height,
        );
      }
      _path.close();
    }
  }

  @override
  bool shouldRepaint(MorphPainter oldDelegate) =>
      oldDelegate.plan != plan ||
      oldDelegate.progress != progress ||
      oldDelegate._color != _color ||
      !listEquals(oldDelegate._shadows, _shadows) ||
      oldDelegate.blendMode != blendMode ||
      oldDelegate.allowOvershoot != allowOvershoot;
}
