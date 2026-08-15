import 'dart:async';

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../geometry/morph_plan.dart';
import '../font/font_selection.dart';
import '../morph_repository.dart';
import '../morph_spring.dart';
import '../rendering/morph_painter.dart';
import 'morph_diagnostics.dart';
import 'morph_icon_frame.dart';

/// Implicitly morphs to each new bundled-font Flutter icon.
final class AnimatedMorphIcon extends StatefulWidget {
  /// Creates an implicitly animated icon.
  ///
  /// Changing [icon] starts a spring transition from the currently visible
  /// shape. A new target can interrupt a transition without snapping back to
  /// the previous endpoint.
  const AnimatedMorphIcon({
    required this.icon,
    this.size,
    this.fill,
    this.weight,
    this.grade,
    this.opticalSize,
    this.color,
    this.shadows,
    this.spring = MorphSprings.snappy,
    this.onEnd,
    this.semanticLabel,
    this.textDirection,
    this.applyTextScaling,
    this.blendMode,
    this.fontWeight,
    super.key,
  }) : assert(fill == null || 0 <= fill && fill <= 1),
       assert(weight == null || weight > 0),
       assert(opticalSize == null || opticalSize > 0);

  /// The icon to display and morph toward when it changes.
  final IconData icon;

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

  /// The physical spring parameters used for transitions.
  final SpringDescription spring;

  /// Called after a transition has fully settled on its target icon.
  /// The callback is not called for the initial icon or an interrupted
  /// transition.
  final VoidCallback? onEnd;

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
  State<AnimatedMorphIcon> createState() => _AnimatedMorphIconState();
}

final class _AnimatedMorphIconState extends State<AnimatedMorphIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late IconData _settledIcon;
  late IconData _fromIcon;
  late IconData _targetIcon;
  AssetBundle? _bundle;
  TextDirection? _direction;
  MorphPlan? _plan;
  var _requestId = 0;
  var _transitioning = false;
  var _preparing = false;
  var _pendingVelocity = 0.0;
  var _disableAnimations = false;
  MorphFontSelection _fontSelection = defaultMorphFontSelection;
  var _effectiveSize = 24.0;
  var _devicePixelRatio = 1.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this, value: 1);
    _settledIcon = widget.icon;
    _fromIcon = widget.icon;
    _targetIcon = widget.icon;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bundle = DefaultAssetBundle.of(context);
    final direction = widget.textDirection ?? Directionality.of(context);
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final fontSelection = _resolveStyle(context).fontSelection;
    final initialized = _bundle != null;
    final changed =
        !identical(bundle, _bundle) ||
        direction != _direction ||
        fontSelection != _fontSelection;
    _bundle = bundle;
    _direction = direction;
    _disableAnimations = disableAnimations;
    _fontSelection = fontSelection;
    if (!initialized) return;
    if (disableAnimations) {
      _settleImmediately(widget.icon);
    } else if (changed) {
      _restartForContext();
    }
  }

  @override
  void didUpdateWidget(AnimatedMorphIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    final fontSelection = _resolveStyle(context).fontSelection;
    final fontSelectionChanged = fontSelection != _fontSelection;
    _fontSelection = fontSelection;
    var directionChanged = false;
    if (oldWidget.textDirection != widget.textDirection) {
      final direction = widget.textDirection ?? Directionality.of(context);
      directionChanged = direction != _direction;
      _direction = direction;
    }
    if (oldWidget.icon != widget.icon) {
      _beginTransition(widget.icon);
    } else if (oldWidget.spring != widget.spring &&
        !_validSpring(widget.spring)) {
      _settleImmediately(widget.icon);
    } else if (directionChanged || fontSelectionChanged) {
      _restartForContext();
    }
  }

  @override
  void dispose() {
    _requestId++;
    _controller.dispose();
    super.dispose();
  }

  void _restartForContext() {
    if (_transitioning) {
      _beginTransition(widget.icon);
      return;
    }
    _settleImmediately(widget.icon);
  }

  void _settleImmediately(IconData target) {
    _requestId++;
    _controller
      ..stop()
      ..value = 1;
    _settledIcon = target;
    _fromIcon = target;
    _targetIcon = target;
    _plan = null;
    _transitioning = false;
    _preparing = false;
    _pendingVelocity = 0;
  }

  void _beginTransition(IconData target) {
    final bundle = _bundle;
    final direction = _direction;
    if (bundle == null || direction == null) return;
    if (_disableAnimations || !_validSpring(widget.spring)) {
      _settleImmediately(target);
      return;
    }
    if (_plan == null && target == _settledIcon) {
      _requestId++;
      _controller.stop();
      _controller.value = 1;
      _plan = null;
      _fromIcon = target;
      _targetIcon = target;
      _transitioning = false;
      _preparing = false;
      return;
    }

    final requestId = ++_requestId;
    final repository = MorphRepository.forBundle(bundle);
    late final Future<MorphPlan> future;
    late final IconData fallbackFrom;
    late final double velocity;
    final currentPlan = _plan;
    if (currentPlan == null || !_transitioning) {
      _controller.stop();
      if (currentPlan == null) _controller.value = 0;
      fallbackFrom = _settledIcon;
      velocity = 0;
      future = repository.planFor(
        _settledIcon,
        target,
        direction,
        _fontSelection,
      );
    } else {
      final snapshot = currentPlan.snapshot(
        clampMorphProgress(_controller.value, allowOvershoot: true),
      );
      fallbackFrom = _targetIcon;
      velocity = _preparing ? _pendingVelocity : _controller.velocity;
      _controller.stop();
      future = repository.planFromShape(
        snapshot,
        target,
        direction,
        _fontSelection,
      );
    }
    _transitioning = true;
    _preparing = true;
    _pendingVelocity = velocity;
    unawaited(
      _acceptPlan(
        requestId,
        future,
        target,
        fallbackFrom,
        velocity,
        widget.spring,
        direction,
      ),
    );
  }

  Future<void> _acceptPlan(
    int requestId,
    Future<MorphPlan> future,
    IconData target,
    IconData fallbackFrom,
    double velocity,
    SpringDescription spring,
    TextDirection direction,
  ) async {
    MorphPlan? plan;
    try {
      plan = await future;
    } catch (error, stack) {
      // Unsupported and malformed fonts animate with ordinary Flutter icons.
      if (!mounted || requestId != _requestId) return;
      reportMorphFailureOnce(
        from: fallbackFrom,
        to: target,
        direction: direction,
        error: error,
        stack: stack,
      );
    }
    if (!mounted || requestId != _requestId) return;

    _controller
      ..stop()
      ..value = 0;
    setState(() {
      _plan = plan;
      _fromIcon = fallbackFrom;
      _targetIcon = target;
      _preparing = false;
    });
    unawaited(_runSpring(requestId, target, velocity, spring));
  }

  Future<void> _runSpring(
    int requestId,
    IconData target,
    double velocity,
    SpringDescription spring,
  ) async {
    final simulation = SpringSimulation(
      spring,
      0,
      1,
      velocity.clamp(-14.0, 14.0).toDouble(),
      snapToEnd: true,
      tolerance: Tolerance(
        distance: _endpointDistanceTolerance(_effectiveSize, _devicePixelRatio),
      ),
    );
    try {
      await _controller.animateWith(simulation).orCancel;
      if (!mounted || requestId != _requestId) return;
      _controller.value = 1;
      setState(() {
        _settledIcon = target;
        _fromIcon = target;
        _targetIcon = target;
        _transitioning = false;
        _pendingVelocity = 0;
      });
      widget.onEnd?.call();
    } on TickerCanceled {
      // A newer target or disposal owns the next frame.
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _resolveStyle(context);
    _effectiveSize = style.size;
    _devicePixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    final plan = _plan;
    return MorphIconFrame(
      from: _fromIcon,
      to: _targetIcon,
      progress: _controller,
      style: style,
      semanticLabel: widget.semanticLabel,
      canonical: plan == null && !_transitioning ? _settledIcon : null,
      painter: plan != null
          ? MorphPainter(
              plan: plan,
              progress: _controller,
              color: style.color,
              shadows: style.shadows,
              blendMode: style.blendMode,
              allowOvershoot: true,
            )
          : null,
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

bool _validSpring(SpringDescription spring) =>
    spring.mass.isFinite &&
    spring.mass > 0 &&
    spring.stiffness.isFinite &&
    spring.stiffness > 0 &&
    spring.damping.isFinite &&
    spring.damping > 0;

double _endpointDistanceTolerance(double size, double devicePixelRatio) {
  final physicalExtent = size * devicePixelRatio;
  if (!physicalExtent.isFinite || physicalExtent <= 0) {
    return Tolerance.defaultTolerance.distance;
  }
  return (0.05 / physicalExtent).clamp(1e-6, 1e-3).toDouble();
}
