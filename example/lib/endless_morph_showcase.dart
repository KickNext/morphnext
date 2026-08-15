import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:morphnext/morphnext.dart';

import 'icon_catalog.dart';
import 'studio.dart';

/// A self-running, full-progress tour through the complete example catalog.
final class EndlessMorphShowcase extends StatefulWidget {
  const EndlessMorphShowcase({
    super.key,
    this.random,
    this.pause = const Duration(milliseconds: 800),
  });

  final math.Random? random;
  final Duration pause;

  @override
  State<EndlessMorphShowcase> createState() => _EndlessMorphShowcaseState();
}

final class _EndlessMorphShowcaseState extends State<EndlessMorphShowcase> {
  late final math.Random _random;
  late IconCatalogEntry _from;
  late IconCatalogEntry _to;
  late IconData _displayedIcon;
  Brightness? _brightness;
  Timer? _pauseTimer;
  var _morphing = false;

  @override
  void initState() {
    super.initState();
    assert(!widget.pause.isNegative);
    assert(heroIconCatalog.length >= 2);
    _random = widget.random ?? math.Random();
    _from = heroIconCatalog[_random.nextInt(heroIconCatalog.length)];
    _to = _pickDifferentFrom(_from.icon);
    _displayedIcon = _from.icon;
    _scheduleNextMorph();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    if (_brightness != null && brightness != _brightness && _morphing) {
      _from = _to;
      _to = _pickDifferentFrom(_from.icon);
      _displayedIcon = _from.icon;
      _morphing = false;
      _scheduleNextMorph();
    }
    _brightness = brightness;
  }

  IconCatalogEntry _pickDifferentFrom(IconData current) {
    IconCatalogEntry candidate;
    do {
      candidate = heroIconCatalog[_random.nextInt(heroIconCatalog.length)];
    } while (candidate.icon == current);
    return candidate;
  }

  void _scheduleNextMorph() {
    _pauseTimer?.cancel();
    _pauseTimer = Timer(widget.pause, () {
      if (!mounted) return;
      setState(() {
        _displayedIcon = _to.icon;
        _morphing = true;
      });
    });
  }

  void _handleMorphEnd() {
    if (!mounted || !_morphing) return;
    setState(() {
      _from = _to;
      _to = _pickDifferentFrom(_from.icon);
      _morphing = false;
    });
    _scheduleNextMorph();
  }

  @override
  void dispose() {
    _pauseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final shortestSide = math.min(
        constraints.maxWidth,
        constraints.maxHeight,
      );
      final availableSize = math.max(0.0, shortestSide - 48);
      final minimumSize = math.min(240.0, availableSize);
      final iconSize = math.min(
        720.0,
        math.max(minimumSize, availableSize * 0.74),
      );

      return SizedBox.expand(
        key: const ValueKey<String>('endless-morph-showcase'),
        child: Center(
          child: SizedBox.square(
            dimension: iconSize,
            child: Center(
              child: AnimatedMorphIcon(
                icon: _displayedIcon,
                size: iconSize,
                color: Studio.text,
                onEnd: _handleMorphEnd,
                semanticLabel: 'Endless random morph preview',
                applyTextScaling: false,
              ),
            ),
          ),
        ),
      );
    },
  );
}
