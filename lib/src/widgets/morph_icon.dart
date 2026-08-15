import 'dart:async';

import 'package:flutter/widgets.dart';

import '../font/font_selection.dart';
import '../geometry/morph_plan.dart';
import '../morph_repository.dart';
import '../rendering/morph_painter.dart';
import 'morph_diagnostics.dart';
import 'morph_icon_frame.dart';

/// Morphs between two bundled-font Flutter icons using controlled progress.
final class MorphIcon extends StatefulWidget {
  /// Creates a controlled icon morph.
  ///
  /// The [progress] value is clamped to the range from zero ([from]) to one
  /// ([to]). Values between the endpoints repaint without rebuilding this
  /// widget.
  const MorphIcon({
    required this.from,
    required this.to,
    required this.progress,
    this.size,
    this.fill,
    this.weight,
    this.grade,
    this.opticalSize,
    this.color,
    this.shadows,
    this.semanticLabel,
    this.textDirection,
    this.applyTextScaling,
    this.blendMode,
    this.fontWeight,
    super.key,
  }) : assert(fill == null || 0 <= fill && fill <= 1),
       assert(weight == null || weight > 0),
       assert(opticalSize == null || opticalSize > 0);

  /// The icon displayed at progress zero.
  final IconData from;

  /// The icon displayed at progress one.
  final IconData to;

  /// Controls the interpolation between [from] and [to].
  final Animation<double> progress;

  /// The icon's logical size.
  ///
  /// Defaults to the ambient [IconThemeData.size].
  final double? size;

  /// The `FILL` variable-font axis value.
  final double? fill;

  /// The `wght` variable-font axis value.
  final double? weight;

  /// The `GRAD` variable-font axis value.
  final double? grade;

  /// The `opsz` variable-font axis value.
  final double? opticalSize;

  /// The icon's color.
  ///
  /// Defaults to the ambient [IconThemeData.color].
  final Color? color;

  /// Shadows painted beneath the morphing outline.
  final List<Shadow>? shadows;

  /// The semantic label announced for this icon.
  ///
  /// When null, the icon is excluded from the semantics tree.
  final String? semanticLabel;

  /// The direction used for icons whose [IconData.matchTextDirection] is true.
  ///
  /// Defaults to the ambient [Directionality].
  final TextDirection? textDirection;

  /// Whether the icon size follows the ambient text scaler.
  ///
  /// Defaults to [IconThemeData.applyTextScaling], then to false.
  final bool? applyTextScaling;

  /// Blend mode applied to the icon foreground.
  final BlendMode? blendMode;

  /// Selects a static font face when the family declares multiple weights.
  final FontWeight? fontWeight;

  @override
  State<MorphIcon> createState() => _MorphIconState();
}

final class _MorphIconState extends State<MorphIcon> {
  AssetBundle? _bundle;
  TextDirection? _direction;
  MorphPlan? _plan;
  MorphFontSelection _fontSelection = defaultMorphFontSelection;
  var _requestId = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bundle = DefaultAssetBundle.of(context);
    final direction = widget.textDirection ?? Directionality.of(context);
    final fontSelection = _resolveStyle(context).fontSelection;
    final geometryContextChanged =
        !identical(bundle, _bundle) ||
        direction != _direction ||
        fontSelection != _fontSelection;
    if (geometryContextChanged) {
      _bundle = bundle;
      _direction = direction;
      _fontSelection = fontSelection;
      _preparePlan();
    }
  }

  @override
  void didUpdateWidget(MorphIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    final fontSelection = _resolveStyle(context).fontSelection;
    if (oldWidget.from != widget.from ||
        oldWidget.to != widget.to ||
        oldWidget.textDirection != widget.textDirection ||
        fontSelection != _fontSelection) {
      _direction = widget.textDirection ?? Directionality.of(context);
      _fontSelection = fontSelection;
      _preparePlan();
    }
  }

  @override
  void dispose() {
    _requestId++;
    super.dispose();
  }

  void _preparePlan() {
    final requestId = ++_requestId;
    final bundle = _bundle;
    final direction = _direction;
    _plan = null;
    if (bundle == null || direction == null || widget.from == widget.to) return;
    unawaited(
      _loadPlan(
        requestId,
        bundle,
        direction,
        _fontSelection,
        widget.from,
        widget.to,
      ),
    );
  }

  Future<void> _loadPlan(
    int requestId,
    AssetBundle bundle,
    TextDirection direction,
    MorphFontSelection fontSelection,
    IconData from,
    IconData to,
  ) async {
    try {
      final plan = await MorphRepository.forBundle(
        bundle,
      ).planFor(from, to, direction, fontSelection);
      if (!mounted || requestId != _requestId) return;
      setState(() => _plan = plan);
    } catch (error, stack) {
      // Native icons remain visible when a font or outline cannot be resolved.
      if (!mounted || requestId != _requestId) return;
      reportMorphFailureOnce(
        from: from,
        to: to,
        direction: direction,
        error: error,
        stack: stack,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _resolveStyle(context);
    final plan = _plan;
    final canPaint = widget.from != widget.to && plan != null;
    final canonical = widget.from == widget.to ? widget.from : null;
    final painter = canPaint
        ? MorphPainter(
            plan: plan,
            progress: widget.progress,
            color: style.color,
            shadows: style.shadows,
            blendMode: style.blendMode,
          )
        : null;

    return MorphIconFrame(
      from: widget.from,
      to: widget.to,
      progress: widget.progress,
      style: style,
      semanticLabel: widget.semanticLabel,
      canonical: canonical,
      painter: painter,
    );
  }

  MorphIconStyle _resolveStyle(BuildContext context) => resolveMorphIconStyle(
    context,
    size: widget.size,
    color: widget.color,
    textDirection: widget.textDirection,
    applyTextScaling: widget.applyTextScaling,
    fill: widget.fill,
    weight: widget.weight,
    grade: widget.grade,
    opticalSize: widget.opticalSize,
    shadows: widget.shadows,
    blendMode: widget.blendMode,
    fontWeight: widget.fontWeight,
  );
}
