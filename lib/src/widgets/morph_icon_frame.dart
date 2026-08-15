import 'package:flutter/widgets.dart';

import '../font/font_selection.dart';
import '../rendering/morph_painter.dart';

typedef MorphIconStyle = ({
  double size,
  Color color,
  TextDirection textDirection,
  MorphFontSelection fontSelection,
  List<Shadow>? shadows,
  BlendMode? blendMode,
});

MorphIconStyle resolveMorphIconStyle(
  BuildContext context, {
  required double? size,
  required Color? color,
  required TextDirection? textDirection,
  required bool? applyTextScaling,
  required double? fill,
  required double? weight,
  required double? grade,
  required double? opticalSize,
  required List<Shadow>? shadows,
  required BlendMode? blendMode,
  required FontWeight? fontWeight,
}) {
  assert(textDirection != null || debugCheckHasDirectionality(context));
  final direction = textDirection ?? Directionality.of(context);
  final theme = IconTheme.of(context);
  final scalesWithText = applyTextScaling ?? theme.applyTextScaling ?? false;
  final unscaledSize = size ?? theme.size ?? 24;
  final effectiveSize = scalesWithText
      ? MediaQuery.textScalerOf(context).scale(unscaledSize)
      : unscaledSize;
  final validSize = effectiveSize.isFinite && effectiveSize >= 0;
  assert(validSize, 'MorphIcon size must be finite and non-negative.');
  final opacity = theme.opacity ?? 1;
  final baseColor = color ?? theme.color!;

  return (
    size: validSize ? effectiveSize : 0,
    color: opacity == 1
        ? baseColor
        : baseColor.withValues(alpha: baseColor.a * opacity),
    textDirection: direction,
    fontSelection: (
      fill: fill ?? theme.fill,
      weight: weight ?? theme.weight,
      grade: grade ?? theme.grade,
      opticalSize: opticalSize ?? theme.opticalSize,
      fontWeight: fontWeight,
    ),
    shadows: shadows ?? theme.shadows,
    blendMode: blendMode,
  );
}

final class MorphIconFrame extends StatelessWidget {
  const MorphIconFrame({
    required this.from,
    required this.to,
    required this.progress,
    required this.style,
    required this.semanticLabel,
    this.canonical,
    this.painter,
    super.key,
  });

  final IconData from;
  final IconData to;
  final Animation<double> progress;
  final MorphIconStyle style;
  final String? semanticLabel;
  final IconData? canonical;
  final MorphPainter? painter;

  @override
  Widget build(BuildContext context) {
    final Widget visual;
    if (canonical case final icon?) {
      visual = _nativeIcon(icon);
    } else if (painter case final morphPainter?) {
      visual = CustomPaint(painter: morphPainter);
    } else {
      visual = AnimatedBuilder(
        animation: progress,
        builder: (context, child) =>
            _nativeIcon(clampMorphProgress(progress.value) < 0.5 ? from : to),
      );
    }

    final excluded = ExcludeSemantics(
      child: SizedBox.square(
        dimension: style.size,
        child: Center(
          child: SizedBox.square(dimension: style.size, child: visual),
        ),
      ),
    );
    return semanticLabel == null
        ? excluded
        : Semantics(label: semanticLabel, image: true, child: excluded);
  }

  Widget _nativeIcon(IconData icon) => Icon(
    icon,
    size: style.size,
    color: style.color,
    fill: style.fontSelection.fill,
    weight: style.fontSelection.weight,
    grade: style.fontSelection.grade,
    opticalSize: style.fontSelection.opticalSize,
    shadows: style.shadows,
    textDirection: style.textDirection,
    applyTextScaling: false,
    blendMode: style.blendMode,
    fontWeight: style.fontSelection.fontWeight,
  );
}
