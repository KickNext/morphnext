import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:morphnext/morphnext.dart';
import 'package:reel_text/reel_text.dart';
import 'package:url_launcher/link.dart';

import 'icon_catalog.dart';
import 'studio.dart';

final class MorphBentoSection extends StatelessWidget {
  const MorphBentoSection({super.key});

  @override
  Widget build(BuildContext context) {
    Theme.of(context).brightness;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        return Column(
          key: const ValueKey<String>('morph-bento-section'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  children: <Widget>[
                    StudioCaption('MORPH IN CONTEXT', color: Studio.primary),
                    SizedBox(height: compact ? 12 : 15),
                    // Caps display with the film's tracking — the same voice
                    // as EVERY PAIR / IS A MORPH. in act two of the preview.
                    Text(
                      'A TINY UNIVERSE OF STATES.',
                      textAlign: TextAlign.center,
                      style: Studio.display(
                        size: compact ? 34 : 46,
                        weight: FontWeight.w800,
                        height: 0.98,
                      ),
                    ),
                    if (!compact) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        'Sync a draft, set the volume, route a journey, tune '
                        'gravity, or watch type and icons move as one.',
                        textAlign: TextAlign.center,
                        style: Studio.body(size: 16, height: 1.5),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(height: compact ? 26 : 36),
            const MorphBentoShowcase(),
          ],
        );
      },
    );
  }
}

/// A gallery of small, useful interactions rather than isolated icon pairs.
final class MorphBentoShowcase extends StatelessWidget {
  const MorphBentoShowcase({super.key});

  static const _gap = 14.0;

  @override
  Widget build(BuildContext context) {
    Theme.of(context).brightness;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final layout = width >= 1080
            ? _wideLayout()
            : width >= 680
            ? _mediumLayout()
            : _compactLayout();
        return KeyedSubtree(
          key: const ValueKey<String>('morph-bento-showcase'),
          child: layout,
        );
      },
    );
  }

  Widget _compactLayout() => Column(
    key: const ValueKey<String>('bento-layout-compact'),
    children: <Widget>[
      SizedBox(height: 450, child: _SportsCard()),
      const SizedBox(height: _gap),
      SizedBox(height: 260, child: _SyncCard()),
      const SizedBox(height: _gap),
      SizedBox(height: 260, child: _WeatherCard()),
      const SizedBox(height: _gap),
      SizedBox(height: 310, child: _TravelCard()),
      const SizedBox(height: _gap),
      SizedBox(height: 290, child: _DrinksCard()),
      const SizedBox(height: _gap),
      SizedBox(height: 300, child: _HatchCard()),
      const SizedBox(height: _gap),
      SizedBox(height: 260, child: _VolumeCard()),
      const SizedBox(height: _gap),
      SizedBox(height: 240, child: _SeasonsCard()),
      const SizedBox(height: _gap),
      SizedBox(height: 300, child: _ReelLoopCard()),
    ],
  );

  Widget _mediumLayout() {
    Widget pair({
      required double height,
      required Widget left,
      required Widget right,
    }) => SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(child: left),
          const SizedBox(width: _gap),
          Expanded(child: right),
        ],
      ),
    );

    return Column(
      key: const ValueKey<String>('bento-layout-medium'),
      children: <Widget>[
        SizedBox(height: 400, child: _SportsCard()),
        const SizedBox(height: _gap),
        pair(height: 260, left: _WeatherCard(), right: _SyncCard()),
        const SizedBox(height: _gap),
        pair(height: 310, left: _TravelCard(), right: _HatchCard()),
        const SizedBox(height: _gap),
        pair(height: 290, left: _DrinksCard(), right: _VolumeCard()),
        const SizedBox(height: _gap),
        pair(height: 300, left: _SeasonsCard(), right: _ReelLoopCard()),
      ],
    );
  }

  Widget _wideLayout() => LayoutBuilder(
    builder: (context, constraints) {
      const columns = 4;
      const rows = 4;
      const rowHeight = 280.0;
      final columnWidth =
          (constraints.maxWidth - _gap * (columns - 1)) / columns;

      Widget tile({
        required int column,
        required int row,
        required Widget child,
        int columnSpan = 1,
        int rowSpan = 1,
      }) => Positioned(
        left: column * (columnWidth + _gap),
        top: row * (rowHeight + _gap),
        width: columnWidth * columnSpan + _gap * (columnSpan - 1),
        height: rowHeight * rowSpan + _gap * (rowSpan - 1),
        child: child,
      );

      return SizedBox(
        key: const ValueKey<String>('bento-layout-wide'),
        height: rowHeight * rows + _gap * (rows - 1),
        child: Stack(
          children: <Widget>[
            tile(
              column: 0,
              row: 0,
              columnSpan: 2,
              rowSpan: 2,
              child: _SportsCard(),
            ),
            tile(column: 2, row: 0, rowSpan: 2, child: _WeatherCard()),
            tile(column: 3, row: 0, child: _SyncCard()),
            tile(column: 3, row: 1, child: _VolumeCard()),
            tile(column: 0, row: 2, columnSpan: 2, child: _TravelCard()),
            tile(column: 2, row: 2, child: _DrinksCard()),
            tile(column: 3, row: 2, child: _HatchCard()),
            tile(column: 0, row: 3, child: _SeasonsCard()),
            tile(column: 1, row: 3, columnSpan: 3, child: _ReelLoopCard()),
          ],
        ),
      );
    },
  );
}

final class _DemoOption {
  const _DemoOption({
    required this.label,
    required this.detail,
    required this.icon,
  });

  final String label;
  final String detail;
  final IconData icon;
}

IconData _catalogIcon(IconCatalogFamily family, String name) => iconCatalog
    .firstWhere((entry) => entry.family == family && entry.name == name)
    .icon;

Color _accentAt(int index) => switch (index % 6) {
  0 => Studio.primary,
  1 => Studio.info,
  2 => Studio.warning,
  3 => Studio.danger,
  4 => Studio.success,
  _ => Studio.violet,
};

final _reelTextShowcaseUri = Uri.parse('https://kicknext.github.io/reel_text/');

final class _BentoCard extends StatelessWidget {
  const _BentoCard({
    super.key,
    this.label,
    required this.accent,
    required this.child,
  });

  final String? label;
  final Color accent;
  final Widget child;

  /// Flat, film-style staging: every card is the page's own ground behind a
  /// hairline, and colour belongs to the subject alone — the caption and the
  /// morphing icons inside, never the surface they sit on.
  @override
  Widget build(BuildContext context) => StudioPanel(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (label != null) ...<Widget>[
          StudioCaption(label!, color: accent),
          const SizedBox(height: 12),
        ],
        Expanded(child: child),
      ],
    ),
  );
}

final class _StudioDropdown extends StatelessWidget {
  const _StudioDropdown({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final int value;
  final List<_DemoOption> options;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Studio.inset,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Studio.border),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
          dropdownColor: Studio.surfaceRaised,
          icon: Icon(Icons.unfold_more_rounded, color: Studio.muted, size: 18),
          style: Studio.mono(
            size: 12,
            color: Studio.text,
            weight: FontWeight.w700,
          ),
          items: <DropdownMenuItem<int>>[
            for (var i = 0; i < options.length; i++)
              DropdownMenuItem<int>(value: i, child: Text(options[i].label)),
          ],
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ),
    ),
  );
}

final class _CompactMorphRow extends StatelessWidget {
  const _CompactMorphRow({
    required this.icon,
    required this.accent,
    required this.semanticLabel,
    required this.body,
    this.size = 70,
  });

  final IconData icon;
  final Color accent;
  final String semanticLabel;
  final Widget body;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      SizedBox.square(
        dimension: size,
        child: Center(
          child: AnimatedMorphIcon(
            icon: icon,
            size: size,
            color: accent,
            semanticLabel: semanticLabel,
            applyTextScaling: false,
          ),
        ),
      ),
      const SizedBox(width: 18),
      Expanded(child: body),
    ],
  );
}

const _syncStates = <_DemoOption>[
  _DemoOption(
    label: 'Local draft',
    detail: 'READY TO SEND',
    icon: Icons.cloud_upload_outlined,
  ),
  _DemoOption(
    label: 'Syncing',
    detail: 'ENCRYPTING · UPLOADING',
    icon: Icons.sync_rounded,
  ),
  _DemoOption(
    label: 'Up to date',
    detail: 'SAVED JUST NOW',
    icon: Icons.cloud_done_rounded,
  ),
];

final class _SyncCard extends StatefulWidget {
  const _SyncCard();

  @override
  State<_SyncCard> createState() => _SyncCardState();
}

final class _SyncCardState extends State<_SyncCard> {
  static const _labelOptions = ReelTextOptions(
    direction: ReelTextDirection.up,
    duration: Duration(milliseconds: 420),
    stagger: Duration(milliseconds: 28),
    exitOffset: Duration(milliseconds: 55),
    bounce: 0.25,
  );
  static const _waitingLabelOptions = ReelTextOptions(
    direction: ReelTextDirection.up,
    duration: Duration(milliseconds: 320),
    stagger: Duration(milliseconds: 20),
    exitOffset: Duration(milliseconds: 45),
    bounce: 0.12,
  );
  static const _resetLabelOptions = ReelTextOptions(
    direction: ReelTextDirection.down,
    duration: Duration(milliseconds: 420),
    stagger: Duration(milliseconds: 28),
    exitOffset: Duration(milliseconds: 55),
    bounce: 0.25,
  );

  late final ReelTextController _actionLabel;
  var _stage = 0;
  var _resetReady = false;

  /// Anchors for the attribution arrow. The caption and the button it points at
  /// live in different columns of the card, so the only way the arrow can be
  /// right at every width is to read where layout actually put them.
  final _bodyKey = GlobalKey();
  final _captionKey = GlobalKey();
  final _actionKey = GlobalKey();
  Offset? _arrowTail;
  Offset? _arrowTip;

  @override
  void initState() {
    super.initState();
    _actionLabel = ReelTextController(initialText: 'Sync');
  }

  void _measureArrow() {
    if (!mounted) {
      return;
    }
    final body = _bodyKey.currentContext?.findRenderObject();
    final caption = _captionKey.currentContext?.findRenderObject();
    final action = _actionKey.currentContext?.findRenderObject();
    if (body is! RenderBox || caption is! RenderBox || action is! RenderBox) {
      return;
    }
    if (!body.hasSize || !caption.hasSize || !action.hasSize) {
      return;
    }
    final captionRect =
        caption.localToGlobal(Offset.zero, ancestor: body) & caption.size;
    final actionRect =
        action.localToGlobal(Offset.zero, ancestor: body) & action.size;
    // Leave just past the caption's last glyph and land under the leading edge
    // of the button, pointing at the label that reel_text actually animates.
    // The tip is kept inside the button's own width and clear of the tail so a
    // long caption on a narrow card cannot fold the curve back on itself.
    final tail = Offset(captionRect.right + 6, captionRect.center.dy);
    final tip = Offset(
      math
          .max(actionRect.left + actionRect.width * 0.24, tail.dx + 10)
          .clamp(actionRect.left + 10, actionRect.right - 10),
      actionRect.bottom + 6,
    );
    if (tail == _arrowTail && tip == _arrowTip) {
      return;
    }
    setState(() {
      _arrowTail = tail;
      _arrowTip = tip;
    });
  }

  @override
  void dispose() {
    _actionLabel.dispose();
    super.dispose();
  }

  Future<void> _sync() async {
    if (_stage == 1) return;
    setState(() {
      _stage = 1;
      _resetReady = false;
    });
    final progress = _actionLabel.startWaiting(
      'Syncing.',
      waiting: const ReelWaiting.ellipsis(
        dots: 2,
        step: Duration(milliseconds: 560),
      ),
      options: _waitingLabelOptions,
    );
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    setState(() => _stage = 2);
    progress.complete('Synced', options: _labelOptions);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    _actionLabel.set('Reset', options: _resetLabelOptions);
    setState(() => _resetReady = true);
  }

  Future<void> _handleAction() async {
    if (_stage == 2) {
      setState(() {
        _stage = 0;
        _resetReady = false;
      });
      _actionLabel.set('Sync', options: _resetLabelOptions);
      return;
    }
    await _sync();
  }

  @override
  Widget build(BuildContext context) {
    final state = _syncStates[_stage];
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureArrow());
    return _BentoCard(
      key: const ValueKey<String>('bento-sync'),
      label: 'CLOUD SYNC',
      accent: Studio.warning,
      child: Stack(
        key: _bodyKey,
        fit: StackFit.expand,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                flex: 5,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    AnimatedMorphIcon(
                      icon: state.icon,
                      size: 82,
                      color: Studio.warning,
                      semanticLabel: 'Cloud sync status',
                      applyTextScaling: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                flex: 6,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      state.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Studio.display(
                        size: 23,
                        weight: FontWeight.w800,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        for (
                          var index = 0;
                          index < _syncStates.length;
                          index++
                        ) ...[
                          Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              height: 4,
                              decoration: BoxDecoration(
                                color: index <= _stage
                                    ? Studio.warning
                                    : Studio.borderBright,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                          if (index != _syncStates.length - 1)
                            const SizedBox(width: 5),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    KeyedSubtree(
                      key: _actionKey,
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          key: const ValueKey<String>('sync-action'),
                          onPressed:
                              _stage == 1 || (_stage == 2 && !_resetReady)
                              ? null
                              : _handleAction,
                          clipBehavior: Clip.antiAlias,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Studio.tone(Studio.warning),
                            side: BorderSide(
                              color: Studio.accentBorder(Studio.warning),
                            ),
                            textStyle: Studio.buttonLabel(
                              color: Studio.warning,
                            ),
                            shape: const StadiumBorder(),
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: SizedBox.expand(
                            child: ClipRect(
                              key: const ValueKey<String>(
                                'sync-action-viewport',
                              ),
                              child: Center(
                                child: ReelText.controller(
                                  key: const ValueKey<String>(
                                    'sync-action-label',
                                  ),
                                  controller: _actionLabel,
                                  style: Studio.buttonLabel(
                                    color: Studio.warning,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // The credit sits in the card's bottom-left corner, where a margin
          // note belongs. Pinning it there also guarantees the arrow always has
          // real rise to work with: inside the icon column it ended up level
          // with the button on wide layouts, leaving nothing to curve through.
          Positioned(
            left: 2,
            bottom: 0,
            child: _ReelTextAttribution(key: _captionKey),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                key: const ValueKey<String>('sync-reel-text-arrow'),
                painter: _arrowTail == null || _arrowTip == null
                    ? null
                    : _AnnotationArrowPainter(
                        color: Studio.warning.withValues(alpha: 0.82),
                        tail: _arrowTail!,
                        tip: _arrowTip!,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _ReelTextAttribution extends StatelessWidget {
  const _ReelTextAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'by ',
            style: Studio.mono(
              size: 10,
              color: Studio.muted,
              weight: FontWeight.w500,
              letterSpacing: 0.25,
              height: 1,
            ),
          ),
          Link(
            key: const ValueKey<String>('sync-reel-text-link'),
            uri: _reelTextShowcaseUri,
            target: LinkTarget.blank,
            builder: (context, followLink) => Semantics(
              button: true,
              label: 'Open the reel_text live demo',
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  key: const ValueKey<String>('reel-text-showcase-link'),
                  behavior: HitTestBehavior.opaque,
                  onTap: followLink,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'reel_text',
                      style: Studio.mono(
                        size: 10,
                        color: Studio.warning,
                        weight: FontWeight.w700,
                        letterSpacing: 0.25,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hand-drawn annotation arrow running from [tail] to [tip], both given in the
/// paint box's own coordinates.
///
/// The whole shape is derived from those two anchors — control points, ink
/// weight and head size are all fractions of the run between them — so the
/// caller decides where the arrow starts and lands and the painter only decides
/// how it is drawn. That is what lets one arrow connect two widgets sitting in
/// different columns and stay correct as the card resizes, instead of being a
/// fixed-size box nudged into place with magic offsets.
final class _AnnotationArrowPainter extends CustomPainter {
  const _AnnotationArrowPainter({
    required this.color,
    required this.tail,
    required this.tip,
  });

  final Color color;
  final Offset tail;
  final Offset tip;

  static const int _shaftSamples = 44;
  static const int _barbSamples = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final delta = tip - tail;
    final span = delta.distance;
    if (span < 12) {
      return;
    }

    // A pen bears down a little harder over a longer run, but the line has to
    // stay one confident stroke rather than turning into a wedge — hence the
    // clamp on both the weight and the head.
    final weight = (span * 0.028).clamp(1.2, 2.2);
    final headLength = (span * 0.16).clamp(7.0, 16.0);

    // The stroke leaves the caption running horizontally, away from its last
    // glyph, and arrives climbing straight into the underside of the target.
    // Fixing both tangents and sizing each handle off the room actually
    // available in that direction is what keeps the curve graceful whether the
    // anchors are far apart or nearly stacked — bowing off the raw delta
    // instead puts a hook in the tail as soon as the run gets short.
    final out = math.max(delta.dx.abs() * 0.75, span * 0.18);
    final up = math.max(delta.dy.abs() * 0.55, span * 0.18);
    final control1 = tail + Offset(out, 0);
    final control2 = tip + Offset(0, up);

    // The shaft stops short of the tip and lets the head cover the join.
    final shaft = <Offset>[];
    for (var i = 0; i <= _shaftSamples; i++) {
      final point = _cubicAt(tail, control1, control2, tip, i / _shaftSamples);
      if ((tip - point).distance < headLength * 0.44) {
        break;
      }
      shaft.add(point);
    }
    if (shaft.length < 2) {
      return;
    }

    final approach = tip - control2;
    final back = -approach / approach.distance;

    // Everything is unioned into one path before it is filled: the colour is
    // translucent, so overlapping fills would blend into visible seams where
    // the barbs meet the shaft.
    var ink = _ribbon(shaft, (t) => weight * (0.18 + 0.32 * t * t));
    for (final part in <Path>[
      Path()
        ..addOval(Rect.fromCircle(center: shaft.first, radius: weight * 0.18)),
      Path()..addOval(Rect.fromCircle(center: tip, radius: weight * 0.5)),
      // The barbs are deliberately uneven in both length and spread. A drawn
      // head never lands symmetrical, and matching them exactly is what makes
      // this kind of arrow read as clip art instead of ink.
      _barb(back, headLength, 0.44, 0.08, weight),
      _barb(back, headLength * 0.82, -0.53, -0.06, weight),
    ]) {
      ink = Path.combine(PathOperation.union, ink, part);
    }

    canvas.drawPath(ink, Paint()..color = color);
  }

  /// One barb of the head, swept back from [tip] by [angle] and bowed by [bow]
  /// so it curves the way a wrist does rather than sitting dead straight.
  Path _barb(
    Offset back,
    double length,
    double angle,
    double bow,
    double weight,
  ) {
    final end = tip + _rotate(back, angle) * length;
    final axis = end - tip;
    final normal = Offset(-axis.dy, axis.dx) / axis.distance;
    final control = tip + axis * 0.5 + normal * (length * bow);
    return _ribbon(<Offset>[
      for (var i = 0; i <= _barbSamples; i++)
        _quadraticAt(tip, control, end, i / _barbSamples),
    ], (t) => weight * (0.5 - 0.38 * t));
  }

  /// Sweeps [points] into a filled outline whose half-width at each sample
  /// comes from [halfWidth], giving the stroke a taper that a constant-weight
  /// [PaintingStyle.stroke] cannot.
  static Path _ribbon(
    List<Offset> points,
    double Function(double t) halfWidth,
  ) {
    final last = points.length - 1;
    final left = <Offset>[];
    final right = <Offset>[];
    for (var i = 0; i <= last; i++) {
      final tangent =
          points[math.min(i + 1, last)] - points[math.max(i - 1, 0)];
      final length = tangent.distance;
      if (length == 0) {
        continue;
      }
      final normal = Offset(-tangent.dy, tangent.dx) / length;
      final half = halfWidth(i / last);
      left.add(points[i] + normal * half);
      right.add(points[i] - normal * half);
    }
    return Path()..addPolygon(<Offset>[...left, ...right.reversed], true);
  }

  static Offset _cubicAt(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
    final u = 1 - t;
    return p0 * (u * u * u) +
        p1 * (3 * u * u * t) +
        p2 * (3 * u * t * t) +
        p3 * (t * t * t);
  }

  static Offset _quadraticAt(Offset p0, Offset p1, Offset p2, double t) {
    final u = 1 - t;
    return p0 * (u * u) + p1 * (2 * u * t) + p2 * (t * t);
  }

  static Offset _rotate(Offset offset, double radians) {
    final cos = math.cos(radians);
    final sin = math.sin(radians);
    return Offset(
      offset.dx * cos - offset.dy * sin,
      offset.dx * sin + offset.dy * cos,
    );
  }

  @override
  bool shouldRepaint(covariant _AnnotationArrowPainter oldDelegate) =>
      color != oldDelegate.color ||
      tail != oldDelegate.tail ||
      tip != oldDelegate.tip;
}

final class _VolumeCard extends StatefulWidget {
  const _VolumeCard();

  @override
  State<_VolumeCard> createState() => _VolumeCardState();
}

final class _VolumeCardState extends State<_VolumeCard> {
  var _volume = 72.0;

  IconData get _icon {
    if (_volume == 0) return Icons.volume_off_rounded;
    if (_volume < 50) return Icons.volume_down_rounded;
    return Icons.volume_up_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final value = _volume.round();
    return _BentoCard(
      key: const ValueKey<String>('bento-volume'),
      label: 'AUDIO LEVEL',
      accent: Studio.violet,
      child: Column(
        children: <Widget>[
          Expanded(
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Center(
                    child: AnimatedMorphIcon(
                      icon: _icon,
                      size: 86,
                      color: Studio.violet,
                      semanticLabel: 'Volume level',
                      applyTextScaling: false,
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                SizedBox(
                  width: 94,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        '$value%',
                        style: Studio.display(
                          size: 38,
                          weight: FontWeight.w800,
                          letterSpacing: -1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      StudioCaption(
                        value == 0 ? 'MUTED' : 'OUTPUT',
                        color: Studio.violet,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Studio.violet,
              inactiveTrackColor: Studio.borderBright,
              thumbColor: Studio.violet,
              overlayColor: Studio.violet.withValues(alpha: 0.12),
              trackHeight: 4,
            ),
            child: Slider(
              key: const ValueKey<String>('volume-slider'),
              value: _volume,
              min: 0,
              max: 100,
              divisions: 100,
              label: '$value%',
              onChanged: (value) => setState(() => _volume = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: <Widget>[
                Text(
                  'MUTE',
                  style: Studio.mono(
                    size: 9,
                    color: Studio.muted,
                    weight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                Text(
                  'FULL',
                  style: Studio.mono(
                    size: 9,
                    color: Studio.muted,
                    weight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final _weatherOptions = <_DemoOption>[
  _DemoOption(
    label: 'Cairo',
    detail: '31° · CLEAR',
    icon: _catalogIcon(IconCatalogFamily.lucide, 'sun'),
  ),
  _DemoOption(
    label: 'Lisbon',
    detail: '22° · PARTLY CLOUDY',
    icon: _catalogIcon(IconCatalogFamily.lucide, 'cloud_sun'),
  ),
  _DemoOption(
    label: 'Portland',
    detail: '14° · RAIN',
    icon: _catalogIcon(IconCatalogFamily.lucide, 'cloud_rain'),
  ),
  _DemoOption(
    label: 'Reykjavík',
    detail: '-3° · SNOW',
    icon: _catalogIcon(IconCatalogFamily.lucide, 'snowflake'),
  ),
  _DemoOption(
    label: 'Kyoto',
    detail: '18° · NIGHT',
    icon: _catalogIcon(IconCatalogFamily.lucide, 'moon'),
  ),
];

final class _WeatherCard extends StatefulWidget {
  const _WeatherCard();

  @override
  State<_WeatherCard> createState() => _WeatherCardState();
}

final class _WeatherCardState extends State<_WeatherCard> {
  var _selected = 1;

  @override
  Widget build(BuildContext context) {
    final weather = _weatherOptions[_selected];
    final accent = _accentAt(_selected + 1);
    return _BentoCard(
      key: const ValueKey<String>('bento-weather'),
      label: 'FORECAST',
      accent: accent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final divider = weather.detail.indexOf(' · ');
          final temperature = divider < 0
              ? weather.detail
              : weather.detail.substring(0, divider);
          final condition = divider < 0
              ? ''
              : weather.detail.substring(divider + 3);
          final picker = _StudioDropdown(
            key: const ValueKey<String>('weather-picker'),
            value: _selected,
            options: _weatherOptions,
            onChanged: (value) => setState(() => _selected = value),
          );
          final icon = AnimatedMorphIcon(
            icon: weather.icon,
            color: accent,
            semanticLabel: 'Selected city weather',
            applyTextScaling: false,
          );

          if (constraints.maxHeight >= 360 && constraints.maxWidth < 360) {
            return Column(
              key: const ValueKey<String>('weather-layout-tall'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  temperature,
                  style: Studio.display(
                    size: 42,
                    weight: FontWeight.w800,
                    letterSpacing: -1.4,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  condition,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Studio.mono(
                    size: 9.5,
                    color: Studio.muted,
                    weight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SizedBox.square(
                      dimension: 128,
                      child: FittedBox(child: icon),
                    ),
                  ),
                ),
                picker,
              ],
            );
          }

          if (constraints.maxWidth < 600) {
            return Column(
              key: const ValueKey<String>('weather-layout-mobile'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: Center(
                    child: SizedBox.square(
                      dimension: math.min(108.0, constraints.maxHeight * 0.56),
                      child: FittedBox(child: icon),
                    ),
                  ),
                ),
                Text(
                  weather.detail,
                  textAlign: TextAlign.center,
                  style: Studio.mono(
                    size: 9.5,
                    color: Studio.muted,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: math.min(360.0, constraints.maxWidth),
                    child: picker,
                  ),
                ),
              ],
            );
          }

          return _CompactMorphRow(
            icon: weather.icon,
            accent: accent,
            semanticLabel: 'Selected city weather',
            size: 66,
            body: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  weather.detail,
                  style: Studio.mono(
                    size: 10.5,
                    color: Studio.muted,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                picker,
              ],
            ),
          );
        },
      ),
    );
  }
}

final _travelOptions = <_DemoOption>[
  const _DemoOption(
    label: 'Walk',
    detail: '42 MIN',
    icon: Icons.directions_walk_rounded,
  ),
  const _DemoOption(
    label: 'Bike',
    detail: '18 MIN',
    icon: Icons.pedal_bike_rounded,
  ),
  const _DemoOption(
    label: 'Drive',
    detail: '11 MIN',
    icon: Icons.directions_car_filled_rounded,
  ),
  const _DemoOption(
    label: 'Train',
    detail: '24 MIN',
    icon: Icons.train_rounded,
  ),
  const _DemoOption(label: 'Fly', detail: '2 H 40', icon: Icons.flight_rounded),
  const _DemoOption(
    label: 'Launch',
    detail: '8 MIN',
    icon: Icons.rocket_launch_rounded,
  ),
];

final class _RouteTrackShape extends SliderTrackShape
    with BaseSliderTrackShape {
  const _RouteTrackShape({required this.stopCount});

  final int stopCount;

  @override
  bool get isRounded => true;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    required TextDirection textDirection,
  }) {
    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final canvas = context.canvas;
    final active = sliderTheme.activeTrackColor ?? Studio.info;
    final inactive = sliderTheme.inactiveTrackColor ?? Studio.borderBright;
    final startX = textDirection == TextDirection.ltr
        ? trackRect.left
        : trackRect.right;
    final endX = textDirection == TextDirection.ltr
        ? trackRect.right
        : trackRect.left;
    final centerY = trackRect.center.dy;

    canvas.drawLine(
      Offset(startX, centerY),
      Offset(endX, centerY),
      Paint()
        ..color = inactive.withValues(alpha: 0.36)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    final activeRect = Rect.fromLTRB(
      math.min(startX, thumbCenter.dx),
      centerY - 2,
      math.max(startX, thumbCenter.dx),
      centerY + 2,
    );
    if (activeRect.width > 0) {
      canvas.drawLine(
        Offset(startX, centerY),
        thumbCenter,
        Paint()
          ..shader = LinearGradient(
            begin: textDirection == TextDirection.ltr
                ? Alignment.centerLeft
                : Alignment.centerRight,
            end: textDirection == TextDirection.ltr
                ? Alignment.centerRight
                : Alignment.centerLeft,
            colors: <Color>[active.withValues(alpha: 0.48), active],
          ).createShader(activeRect)
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
    }

    for (var index = 0; index < stopCount; index++) {
      final fraction = index / (stopCount - 1);
      final x = textDirection == TextDirection.ltr
          ? trackRect.left + trackRect.width * fraction
          : trackRect.right - trackRect.width * fraction;
      final reached = textDirection == TextDirection.ltr
          ? x <= thumbCenter.dx + 0.5
          : x >= thumbCenter.dx - 0.5;
      final stop = Offset(x, centerY);
      canvas.drawCircle(stop, 4, Paint()..color = Studio.surfaceRaised);
      canvas.drawCircle(
        stop,
        reached ? 2.1 : 1.7,
        Paint()..color = reached ? active : inactive.withValues(alpha: 0.62),
      );
    }
  }
}

final class _RouteThumbShape extends SliderComponentShape {
  const _RouteThumbShape();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.square(24);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final accent = sliderTheme.thumbColor ?? Studio.info;
    final activation = activationAnimation.value;
    canvas.drawCircle(
      center,
      10 + activation * 2,
      Paint()..color = accent.withValues(alpha: 0.10 + activation * 0.06),
    );
    canvas.drawCircle(center, 7.5, Paint()..color = Studio.surfaceRaised);
    canvas.drawCircle(center, 5.2, Paint()..color = accent);
  }
}

final class _TravelRouteRail extends StatelessWidget {
  const _TravelRouteRail({
    required this.selected,
    required this.compact,
    required this.onChanged,
  });

  final int selected;
  final bool compact;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: compact ? 44 : 48,
    child: SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: Studio.info,
        inactiveTrackColor: Studio.borderBright,
        thumbColor: Studio.info,
        overlayColor: Studio.accentWash(Studio.info, alpha: 0.10),
        trackHeight: 4,
        trackShape: _RouteTrackShape(stopCount: _travelOptions.length),
        thumbShape: const _RouteThumbShape(),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
        tickMarkShape: SliderTickMarkShape.noTickMark,
      ),
      child: Slider(
        key: const ValueKey<String>('travel-route-slider'),
        value: selected.toDouble(),
        min: 0,
        max: (_travelOptions.length - 1).toDouble(),
        divisions: _travelOptions.length - 1,
        label: _travelOptions[selected].label,
        onChanged: (value) => onChanged(value.round()),
      ),
    ),
  );
}

final class _TravelCard extends StatefulWidget {
  const _TravelCard();

  @override
  State<_TravelCard> createState() => _TravelCardState();
}

final class _TravelCardState extends State<_TravelCard> {
  var _selected = 2;

  @override
  Widget build(BuildContext context) {
    final option = _travelOptions[_selected];
    return _BentoCard(
      key: const ValueKey<String>('bento-travel'),
      label: 'ROUTE PLANNER',
      accent: Studio.info,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final rail = _TravelRouteRail(
            selected: _selected,
            compact: compact,
            onChanged: (value) => setState(() => _selected = value),
          );
          final modeLine = SizedBox(
            key: const ValueKey<String>('travel-mode-line'),
            height: compact ? 28 : 32,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Align(
                  alignment: Alignment.center,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Text(
                      option.label,
                      key: ValueKey<String>(option.label),
                      textAlign: TextAlign.center,
                      style: Studio.display(
                        size: compact ? 17 : 21,
                        weight: FontWeight.w700,
                        letterSpacing: -0.45,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    option.detail,
                    style: Studio.mono(
                      size: compact ? 7.5 : 8.5,
                      color: Studio.muted,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          );
          final icon = AnimatedMorphIcon(
            icon: option.icon,
            size: compact ? 112 : 138,
            color: Studio.info,
            semanticLabel: 'Selected travel mode',
            applyTextScaling: false,
          );

          if (compact) {
            return Column(
              key: const ValueKey<String>('travel-layout-mobile'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: Align(alignment: Alignment.topCenter, child: icon),
                ),
                modeLine,
                const SizedBox(height: 2),
                rail,
              ],
            );
          }

          return Row(
            key: const ValueKey<String>('travel-layout-horizontal'),
            children: <Widget>[
              Expanded(flex: 5, child: Center(child: icon)),
              const SizedBox(width: 30),
              Expanded(
                flex: 6,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[modeLine, const SizedBox(height: 9), rail],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

final _hatchOptions = <_DemoOption>[
  const _DemoOption(label: 'Egg', detail: 'DORMANT', icon: Icons.egg_rounded),
  _DemoOption(
    label: 'Tracks',
    detail: 'SOMETHING MOVED',
    icon: _catalogIcon(IconCatalogFamily.cupertino, 'paw'),
  ),
  _DemoOption(
    label: 'Cat',
    detail: 'FRIENDLY HATCH',
    icon: _catalogIcon(IconCatalogFamily.lucide, 'cat'),
  ),
  _DemoOption(
    label: 'Dragon',
    detail: 'LEGENDARY HATCH',
    icon: _catalogIcon(IconCatalogFamily.fontAwesome, 'dragon'),
  ),
];

final class _HatchCard extends StatefulWidget {
  const _HatchCard();

  @override
  State<_HatchCard> createState() => _HatchCardState();
}

final class _HatchCardState extends State<_HatchCard> {
  var _stage = 0;

  void _advance() => setState(
    () => _stage = _stage + 1 == _hatchOptions.length ? 0 : _stage + 1,
  );

  @override
  Widget build(BuildContext context) {
    final option = _hatchOptions[_stage];
    final accent = _accentAt(_stage + 2);
    return _BentoCard(
      key: const ValueKey<String>('bento-hatch'),
      label: 'TINY QUEST',
      accent: accent,
      child: Column(
        children: <Widget>[
          Expanded(
            child: AnimatedAlign(
              alignment: Alignment(
                _stage == _hatchOptions.length - 1 ? -0.10 : 0,
                0,
              ),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              child: AnimatedMorphIcon(
                icon: option.icon,
                size: 104,
                color: accent,
                semanticLabel: 'Creature hatch stage',
                applyTextScaling: false,
              ),
            ),
          ),
          Text(
            option.detail,
            style: Studio.mono(
              size: 10,
              color: Studio.muted,
              weight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: StudioButton(
              onPressed: _advance,
              accent: accent,
              child: Text(
                _stage == _hatchOptions.length - 1 ? 'Reset' : 'Hatch',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final _drinkOptions = <_DemoOption>[
  const _DemoOption(
    label: 'Coffee',
    detail: 'MORNING',
    icon: Icons.coffee_rounded,
  ),
  _DemoOption(
    label: 'Tea',
    detail: 'AFTERNOON',
    icon: _catalogIcon(IconCatalogFamily.lucide, 'cup_soda'),
  ),
  _DemoOption(
    label: 'Beer',
    detail: 'TAP',
    icon: _catalogIcon(IconCatalogFamily.lucide, 'beer'),
  ),
  _DemoOption(
    label: 'Martini',
    detail: 'SHAKEN',
    icon: _catalogIcon(IconCatalogFamily.lucide, 'martini'),
  ),
  _DemoOption(
    label: 'Wine',
    detail: 'HOUSE RED',
    icon: _catalogIcon(IconCatalogFamily.fontAwesome, 'wine_glass'),
  ),
];

final class _DrinksCard extends StatefulWidget {
  const _DrinksCard();

  @override
  State<_DrinksCard> createState() => _DrinksCardState();
}

final class _DrinksCardState extends State<_DrinksCard> {
  var _selected = 0;

  Widget _drinkChoice(int index, Color accent) {
    final option = _drinkOptions[index];
    final selected = index == _selected;
    return Semantics(
      button: true,
      selected: selected,
      label: option.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          key: ValueKey<String>('drink-choice-$index'),
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _selected = index),
          child: SizedBox(
            width: 36,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                AnimatedScale(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  scale: selected ? 1.16 : 1,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: selected ? 1 : 0.46,
                    child: Icon(
                      option.icon,
                      size: 22,
                      color: selected ? accent : Studio.text,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 1,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    scale: selected ? 1 : 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: const SizedBox(width: 16, height: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final drink = _drinkOptions[_selected];
    final accent = Studio.danger;
    return _BentoCard(
      key: const ValueKey<String>('bento-drinks'),
      label: 'BAR CART',
      accent: accent,
      child: Column(
        children: <Widget>[
          Expanded(
            child: Row(
              children: <Widget>[
                Expanded(
                  flex: 5,
                  child: Center(
                    child: AnimatedMorphIcon(
                      icon: drink.icon,
                      size: 84,
                      color: accent,
                      semanticLabel: 'Selected drink',
                      applyTextScaling: false,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        drink.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Studio.display(
                          size: 21,
                          weight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        drink.detail,
                        style: Studio.mono(
                          size: 8.5,
                          color: Studio.muted,
                          weight: FontWeight.w800,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              for (var index = 0; index < _drinkOptions.length; index++)
                _drinkChoice(index, accent),
            ],
          ),
        ],
      ),
    );
  }
}

final class _BallFrame {
  const _BallFrame({this.height = 0, this.compression = 0});

  final double height;
  final double compression;
}

final class _BallPhysics {
  const _BallPhysics({
    required this.label,
    required this.icon,
    required this.launchHeight,
    required this.restitution,
    required this.bounces,
    required this.gravity,
  });

  final String label;
  final IconData icon;
  final double launchHeight;
  final double restitution;
  final int bounces;
  final double gravity;

  double get _firstFlightMilliseconds =>
      620 * math.sqrt(launchHeight / gravity);

  double get _contactMilliseconds => 34 + 24 * restitution;

  double get _impactCompression => 0.015 + 0.06 * restitution;

  double get _totalMilliseconds {
    var flight = _firstFlightMilliseconds;
    var total = 0.0;
    for (var bounce = 0; bounce < bounces; bounce++) {
      total += flight + _contactMilliseconds;
      flight *= restitution;
    }
    return total;
  }

  Duration get duration => Duration(milliseconds: _totalMilliseconds.round());

  _BallFrame frameAt(double progress) {
    final clamped = progress.clamp(0.0, 1.0);
    if (clamped == 0 || clamped == 1) return const _BallFrame();

    var remaining = clamped * _totalMilliseconds;
    var flightMilliseconds = _firstFlightMilliseconds;
    var peakHeight = launchHeight;
    for (var bounce = 0; bounce < bounces; bounce++) {
      if (remaining <= flightMilliseconds) {
        final phase = (remaining / flightMilliseconds).clamp(0.0, 1.0);
        return _BallFrame(height: peakHeight * 4 * phase * (1 - phase));
      }
      remaining -= flightMilliseconds;

      if (remaining <= _contactMilliseconds) {
        final phase = (remaining / _contactMilliseconds).clamp(0.0, 1.0);
        return _BallFrame(
          compression: _impactCompression * math.sin(math.pi * phase),
        );
      }
      remaining -= _contactMilliseconds;
      flightMilliseconds *= restitution;
      peakHeight *= restitution * restitution;
    }
    return const _BallFrame();
  }
}

final _ballPhysics = <_BallPhysics>[
  _BallPhysics(
    label: 'Volley',
    icon: _catalogIcon(IconCatalogFamily.fontAwesome, 'volleyball'),
    launchHeight: 0.94,
    restitution: 0.76,
    bounces: 3,
    gravity: 0.92,
  ),
  _BallPhysics(
    label: 'Basket',
    icon: _catalogIcon(IconCatalogFamily.fontAwesome, 'basketball'),
    launchHeight: 0.88,
    restitution: 0.64,
    bounces: 3,
    gravity: 1,
  ),
  _BallPhysics(
    label: 'Soccer',
    icon: _catalogIcon(IconCatalogFamily.fontAwesome, 'futbol'),
    launchHeight: 0.82,
    restitution: 0.52,
    bounces: 2,
    gravity: 1.04,
  ),
  _BallPhysics(
    label: 'Baseball',
    icon: _catalogIcon(IconCatalogFamily.fontAwesome, 'baseball'),
    launchHeight: 0.76,
    restitution: 0.44,
    bounces: 2,
    gravity: 1.12,
  ),
  _BallPhysics(
    label: 'Football',
    icon: _catalogIcon(IconCatalogFamily.fontAwesome, 'football'),
    launchHeight: 0.68,
    restitution: 0.34,
    bounces: 2,
    gravity: 1.08,
  ),
  _BallPhysics(
    label: 'Bowling',
    icon: _catalogIcon(IconCatalogFamily.fontAwesome, 'bowling_ball'),
    launchHeight: 0.46,
    restitution: 0.12,
    bounces: 1,
    gravity: 1.32,
  ),
  _BallPhysics(
    label: 'Hockey',
    icon: _catalogIcon(IconCatalogFamily.fontAwesome, 'hockey_puck'),
    launchHeight: 0.34,
    restitution: 0.05,
    bounces: 1,
    gravity: 1.45,
  ),
];

const _ballChoiceRotations = <double>[
  -0.12,
  0.05,
  -0.07,
  0.09,
  -0.05,
  0.08,
  -0.10,
];

final class _BallShadowPainter extends CustomPainter {
  _BallShadowPainter({
    required this.animation,
    required this.physics,
    required this.iconSize,
    required this.color,
    required this.accent,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final _BallPhysics physics;
  final double iconSize;
  final Color color;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = physics.frameAt(animation.value);
    final heightRatio = frame.height;
    final floorY = size.height - 1.5;
    canvas.drawLine(
      Offset(size.width * 0.34, floorY),
      Offset(size.width * 0.66, floorY),
      Paint()
        ..shader =
            LinearGradient(
              colors: <Color>[
                accent.withValues(alpha: 0),
                accent.withValues(alpha: 0.34),
                accent.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromLTWH(
                size.width * 0.34,
                floorY - 1,
                size.width * 0.32,
                2,
              ),
            )
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
    final width =
        iconSize * (0.34 + (1 - heightRatio) * 0.2 + frame.compression * 0.7);
    final height = math.max(4.0, iconSize * 0.065);
    final outerRect = Rect.fromLTWH(
      (size.width - width) / 2,
      size.height - height,
      width,
      height,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(outerRect, const Radius.circular(99)),
      Paint()
        ..color = color.withValues(
          alpha: 0.025 + (1 - heightRatio) * 0.055 + frame.compression * 0.55,
        ),
    );
    final innerWidth = width * 0.68;
    final innerHeight = height * 0.55;
    final innerRect = Rect.fromLTWH(
      (size.width - innerWidth) / 2,
      size.height - innerHeight,
      innerWidth,
      innerHeight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(innerRect, const Radius.circular(99)),
      Paint()
        ..color = color.withValues(
          alpha: 0.025 + (1 - heightRatio) * 0.075 + frame.compression * 0.7,
        ),
    );
  }

  @override
  bool shouldRepaint(_BallShadowPainter oldDelegate) =>
      oldDelegate.animation != animation ||
      oldDelegate.physics != physics ||
      oldDelegate.iconSize != iconSize ||
      oldDelegate.color != color ||
      oldDelegate.accent != accent;
}

final class _BallFlowDelegate extends FlowDelegate {
  _BallFlowDelegate({
    required this.animation,
    required this.physics,
    required this.iconSize,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final _BallPhysics physics;
  final double iconSize;

  @override
  BoxConstraints getConstraintsForChild(
    int index,
    BoxConstraints constraints,
  ) => BoxConstraints.tightFor(width: iconSize, height: iconSize);

  @override
  void paintChildren(FlowPaintingContext context) {
    final frame = physics.frameAt(animation.value);
    final travelHeight = math.max(0.0, context.size.height - iconSize * 1.1);
    final lift = travelHeight * frame.height;
    final x = (context.size.width - iconSize) / 2;
    final y = context.size.height - iconSize * 1.1 - lift;
    final scaleX = 1 + frame.compression * 0.62;
    final scaleY = 1 - frame.compression;
    final transform = Matrix4.identity()
      ..translateByDouble(x + iconSize / 2, y + iconSize, 0, 1)
      ..scaleByDouble(scaleX, scaleY, 1, 1)
      ..translateByDouble(-iconSize / 2, -iconSize, 0, 1);
    context.paintChild(0, transform: transform);
  }

  @override
  bool shouldRepaint(_BallFlowDelegate oldDelegate) =>
      oldDelegate.animation != animation ||
      oldDelegate.physics != physics ||
      oldDelegate.iconSize != iconSize;
}

final class _SportsCard extends StatefulWidget {
  const _SportsCard();

  @override
  State<_SportsCard> createState() => _SportsCardState();
}

final class _SportsCardState extends State<_SportsCard>
    with SingleTickerProviderStateMixin {
  var _selected = 1;
  int? _hoveredChoice;
  var _dropRequest = 0;
  late final AnimationController _bounceController;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: _ballPhysics[_selected].duration,
      value: 1,
    );
  }

  void _drop() {
    if (_bounceController.isAnimating) return;
    final request = ++_dropRequest;
    _bounceController
      ..stop()
      ..duration = _ballPhysics[_selected].duration
      ..value = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && request == _dropRequest) {
        _bounceController.forward();
      }
    });
  }

  void _selectPhysics(int value) {
    if (value == _selected) return;
    _dropRequest++;
    _bounceController
      ..stop()
      ..value = 1;
    setState(() => _selected = value);
  }

  Widget _bounceStage(_BallPhysics physics, {required double maxIconSize}) =>
      LayoutBuilder(
        builder: (context, constraints) {
          final iconSize = math.min(maxIconSize, constraints.maxWidth * 0.64);
          return RepaintBoundary(
            child: CustomPaint(
              painter: _BallShadowPainter(
                animation: _bounceController,
                physics: physics,
                iconSize: iconSize,
                color: Studio.text,
                accent: Studio.success,
              ),
              child: Flow(
                key: const ValueKey<String>('physics-stage'),
                delegate: _BallFlowDelegate(
                  animation: _bounceController,
                  physics: physics,
                  iconSize: iconSize,
                ),
                children: <Widget>[
                  RepaintBoundary(
                    child: Semantics(
                      button: true,
                      excludeSemantics: true,
                      label: 'Tap selected ball to bounce',
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          key: const ValueKey<String>('physics-drop'),
                          behavior: HitTestBehavior.opaque,
                          onTap: _drop,
                          child: AnimatedMorphIcon(
                            key: const ValueKey<String>('physics-ball'),
                            icon: physics.icon,
                            size: iconSize,
                            color: Studio.success,
                            semanticLabel: 'Selected sport',
                            applyTextScaling: false,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

  Widget _physicsChoice(
    int index,
    double diameter, {
    required double rotation,
  }) {
    final physics = _ballPhysics[index];
    final selected = index == _selected;
    final hovered = index == _hoveredChoice;
    return Semantics(
      button: true,
      selected: selected,
      label: physics.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hoveredChoice = index),
        onExit: (_) {
          if (_hoveredChoice == index) {
            setState(() => _hoveredChoice = null);
          }
        },
        child: GestureDetector(
          key: ValueKey<String>('physics-choice-$index'),
          behavior: HitTestBehavior.opaque,
          onTap: () => _selectPhysics(index),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            scale: selected ? 1.06 : (hovered ? 1.03 : 1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? Studio.accentWash(Studio.success, alpha: 0.08)
                    : hovered
                    ? Studio.accentWash(Studio.success, alpha: 0.035)
                    : Studio.transparent,
                border: Border.all(
                  color: selected
                      ? Studio.accentBorder(Studio.success, alpha: 0.42)
                      : hovered
                      ? Studio.accentBorder(Studio.success, alpha: 0.16)
                      : Studio.transparent,
                ),
              ),
              child: Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  opacity: selected ? 1 : (hovered ? 0.76 : 0.42),
                  child: AnimatedRotation(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutBack,
                    turns: selected ? 0 : rotation / (2 * math.pi),
                    child: Icon(
                      physics.icon,
                      size: diameter * 0.54,
                      color: selected ? Studio.success : Studio.text,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _physicsChoices({required bool compact}) => LayoutBuilder(
    builder: (context, constraints) {
      final diameter = math.min(
        compact ? 44.0 : 42.0,
        math.max(28.0, constraints.maxWidth / 7),
      );
      final spacing = math.min(
        compact ? 4.0 : 8.0,
        math.max(0.0, (constraints.maxWidth - diameter * 7) / 6),
      );
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          for (var index = 0; index < _ballPhysics.length; index++) ...<Widget>[
            if (index > 0) SizedBox(width: spacing),
            _physicsChoice(
              index,
              diameter,
              rotation: _ballChoiceRotations[index],
            ),
          ],
        ],
      );
    },
  );

  @override
  void dispose() {
    _dropRequest++;
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final physics = _ballPhysics[_selected];
    return _BentoCard(
      key: const ValueKey<String>('bento-sports'),
      label: 'PHYSICS LAB',
      accent: Studio.success,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 500;
          return Column(
            children: <Widget>[
              Expanded(
                child: _bounceStage(physics, maxIconSize: compact ? 136 : 148),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: compact ? 44 : 42,
                child: _physicsChoices(compact: compact),
              ),
            ],
          );
        },
      ),
    );
  }
}

final _seasonOptions = <_DemoOption>[
  const _DemoOption(
    label: 'Winter',
    detail: 'DEC — FEB',
    icon: Icons.ac_unit_rounded,
  ),
  const _DemoOption(
    label: 'Spring',
    detail: 'MAR — MAY',
    icon: Icons.local_florist_rounded,
  ),
  const _DemoOption(
    label: 'Summer',
    detail: 'JUN — AUG',
    icon: Icons.wb_sunny_rounded,
  ),
  const _DemoOption(
    label: 'Autumn',
    detail: 'SEP — NOV',
    icon: Icons.eco_rounded,
  ),
];

final class _SeasonsCard extends StatefulWidget {
  const _SeasonsCard();

  @override
  State<_SeasonsCard> createState() => _SeasonsCardState();
}

final class _SeasonsCardState extends State<_SeasonsCard> {
  var _selected = 2;

  @override
  Widget build(BuildContext context) {
    final season = _seasonOptions[_selected];
    final accent = _accentAt(_selected + 1);
    return _BentoCard(
      key: const ValueKey<String>('bento-seasons'),
      label: 'YEAR WHEEL',
      accent: accent,
      child: Column(
        children: <Widget>[
          Expanded(
            child: Center(
              child: AnimatedMorphIcon(
                icon: season.icon,
                size: 84,
                color: accent,
                semanticLabel: 'Selected season',
                applyTextScaling: false,
              ),
            ),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 7,
            runSpacing: 7,
            children: <Widget>[
              for (var i = 0; i < _seasonOptions.length; i++)
                ChoiceChip(
                  key: ValueKey<String>('season-choice-$i'),
                  label: Text(
                    _seasonOptions[i].label,
                    style: Studio.buttonLabel(
                      color: i == _selected
                          ? Studio.onAccent(Studio.primary)
                          : Studio.text,
                    ),
                  ),
                  selected: i == _selected,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _selected = i),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

const _reelLoopFrames = <_DemoOption>[
  _DemoOption(label: 'reel', detail: 'FILM', icon: Icons.movie_filter_rounded),
  _DemoOption(label: 'text', detail: 'TYPE', icon: Icons.text_fields_rounded),
  _DemoOption(
    label: 'reel',
    detail: 'MOTION',
    icon: Icons.slow_motion_video_rounded,
  ),
  _DemoOption(label: 'text', detail: 'CAPTION', icon: Icons.subtitles_rounded),
  _DemoOption(
    label: 'reel',
    detail: 'CUT',
    icon: Icons.video_collection_rounded,
  ),
  _DemoOption(
    label: 'text',
    detail: 'COPY',
    icon: Icons.closed_caption_rounded,
  ),
];

final class _ReelLoopCard extends StatefulWidget {
  const _ReelLoopCard();

  @override
  State<_ReelLoopCard> createState() => _ReelLoopCardState();
}

final class _ReelLoopCardState extends State<_ReelLoopCard> {
  static const _step = Duration(milliseconds: 1900);
  static const _rollOptions = ReelTextOptions(
    direction: ReelTextDirection.up,
    duration: Duration(milliseconds: 560),
    stagger: Duration(milliseconds: 58),
    exitOffset: Duration(milliseconds: 70),
    curve: Cubic(0.22, 1, 0.36, 1),
    bounce: 0.18,
    skipUnchanged: true,
  );

  late final ReelTextController _word;
  Timer? _loopTimer;
  var _index = 0;
  var _hovered = false;

  @override
  void initState() {
    super.initState();
    _word = ReelTextController(initialText: _reelLoopFrames.first.label);
    _loopTimer = Timer.periodic(_step, (_) => _advance());
  }

  void _advance() {
    if (!mounted) return;
    final next = (_index + 1) % _reelLoopFrames.length;
    setState(() => _index = next);
    _word.set(_reelLoopFrames[next].label, options: _rollOptions);
  }

  @override
  void dispose() {
    _loopTimer?.cancel();
    _word.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frame = _reelLoopFrames[_index];
    return Link(
      key: const ValueKey<String>('reel-loop-link'),
      uri: _reelTextShowcaseUri,
      target: LinkTarget.blank,
      builder: (context, followLink) => Semantics(
        button: true,
        label: 'Open the reel_text live demo',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            key: const ValueKey<String>('reel-loop-card-link'),
            behavior: HitTestBehavior.opaque,
            onTap: followLink,
            child: _BentoCard(
              key: const ValueKey<String>('bento-reel-loop'),
              accent: Studio.primary,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 520;
                  final iconSize = wide
                      ? math.min(156.0, constraints.maxHeight * 0.72)
                      : math.min(
                          112.0,
                          math.max(82.0, constraints.maxWidth * 0.28),
                        );
                  final wordSize = wide
                      ? math.min(154.0, constraints.maxHeight * 0.67)
                      : math.min(
                          88.0,
                          math.max(74.0, constraints.maxWidth * 0.21),
                        );
                  return Stack(
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsets.only(right: wide ? 64 : 50),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              flex: wide ? 4 : 5,
                              child: Center(
                                child: AnimatedMorphIcon(
                                  key: const ValueKey<String>('reel-loop-icon'),
                                  icon: frame.icon,
                                  size: iconSize,
                                  color: Studio.primary,
                                  semanticLabel: 'Synchronized reel icon',
                                  applyTextScaling: false,
                                ),
                              ),
                            ),
                            SizedBox(width: wide ? 42 : 20),
                            Expanded(
                              flex: wide ? 6 : 7,
                              child: SizedBox(
                                height: wordSize * 1.22,
                                child: ClipRect(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: ReelText.controller(
                                      key: const ValueKey<String>(
                                        'reel-loop-word',
                                      ),
                                      controller: _word,
                                      semanticsLabel:
                                          'Synchronized reel text label',
                                      style: Studio.display(
                                        size: wordSize,
                                        color: Studio.text,
                                        weight: FontWeight.w800,
                                        letterSpacing: wide ? -5 : -2.4,
                                        height: 1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: wide ? 10 : 2,
                        bottom: 0,
                        child: Center(
                          child: AnimatedSlide(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            offset: _hovered
                                ? const Offset(0.12, -0.12)
                                : Offset.zero,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 180),
                              opacity: _hovered ? 1 : 0.62,
                              child: CustomPaint(
                                key: const ValueKey<String>(
                                  'reel-loop-link-arrow',
                                ),
                                size: Size.square(wide ? 46 : 36),
                                painter: _OutboundLinkArrowPainter(
                                  color: Studio.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _OutboundLinkArrowPainter extends CustomPainter {
  const _OutboundLinkArrowPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = size.shortestSide * 0.18;
    final tip = Offset(size.width - inset, inset);
    final wing = size.shortestSide * 0.34;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(inset, size.height - inset)
      ..lineTo(tip.dx, tip.dy)
      ..moveTo(tip.dx - wing, tip.dy)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(tip.dx, tip.dy + wing);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_OutboundLinkArrowPainter oldDelegate) =>
      oldDelegate.color != color;
}
