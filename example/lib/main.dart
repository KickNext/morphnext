import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugPaintSizeEnabled;
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:morphnext/morphnext.dart';

import 'bento_showcase.dart';
import 'endless_morph_showcase.dart';
import 'icon_browser.dart';
import 'icon_catalog.dart';
import 'install_block.dart';
import 'site_chrome.dart';
import 'studio.dart';

typedef _MorphPair = ({
  String label,
  String fromLabel,
  String toLabel,
  IconData from,
  IconData to,
});
typedef _SpringChoice = ({String label, SpringDescription spring});

enum _HeroMotion { spring, manual }

const _showDebugLayoutOverlay = bool.fromEnvironment('MORPHNEXT_DEBUG_LAYOUT');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPaintSizeEnabled = _showDebugLayoutOverlay;
  usePathUrlStrategy();
  const themePreferenceStore = ThemePreferenceStore();
  final savedBrightness = await loadSavedBrightness(themePreferenceStore);
  GoogleFonts.instrumentSans(fontWeight: FontWeight.w600);
  GoogleFonts.instrumentSans(fontWeight: FontWeight.w700);
  GoogleFonts.instrumentSans(fontWeight: FontWeight.w800);
  GoogleFonts.jetBrainsMono();
  GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w700);
  await GoogleFonts.pendingFonts();
  runApp(
    MorphnextExampleApp(
      initialBrightnessOverride: savedBrightness,
      themePreferenceStore: themePreferenceStore,
    ),
  );
}

class MorphnextExampleApp extends StatefulWidget {
  const MorphnextExampleApp({
    super.key,
    this.initialLocation,
    this.initialBrightnessOverride,
    this.themePreferenceStore = const ThemePreferenceStore(),
    this.loadLiveMetadata = true,
    this.useGoogleFonts = true,
  });

  final String? initialLocation;
  final Brightness? initialBrightnessOverride;
  final ThemePreferenceStore themePreferenceStore;
  final bool loadLiveMetadata;
  final bool useGoogleFonts;

  @override
  State<MorphnextExampleApp> createState() => _MorphnextExampleAppState();
}

class _MorphnextExampleAppState extends State<MorphnextExampleApp>
    with WidgetsBindingObserver {
  late final GoRouter _router;
  Brightness? _brightnessOverride;

  Brightness get _brightness =>
      _brightnessOverride ??
      WidgetsBinding.instance.platformDispatcher.platformBrightness;

  @override
  void initState() {
    super.initState();
    _brightnessOverride = widget.initialBrightnessOverride;
    WidgetsBinding.instance.addObserver(this);
    _router = _buildRouter(
      initialLocation: widget.initialLocation,
      loadLiveMetadata: widget.loadLiveMetadata,
      onBrightnessChanged: _setBrightness,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    if (_brightnessOverride == null && mounted) setState(() {});
  }

  void _setBrightness(Brightness brightness) {
    setState(() => _brightnessOverride = brightness);
    unawaited(_saveBrightness(brightness));
  }

  Future<void> _saveBrightness(Brightness brightness) async {
    try {
      await widget.themePreferenceStore.saveBrightness(brightness);
    } on Object catch (error) {
      debugPrint('Could not save theme: $error');
    }
  }

  ThemeData _theme() {
    final scheme = Studio.scheme;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Studio.background,
      sliderTheme: SliderThemeData(
        activeTrackColor: Studio.focus,
        thumbColor: Studio.focus,
        inactiveTrackColor: Studio.border,
        overlayColor: Studio.focus.withValues(alpha: 0.10),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStatePropertyAll(Studio.onAccent(Studio.primary)),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Studio.primary
              : Studio.border,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          side: WidgetStatePropertyAll(BorderSide(color: Studio.border)),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? Studio.onAccent(Studio.primary)
                : Studio.muted,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? Studio.primary
                : Studio.transparent,
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              height: 1,
              leadingDistribution: TextLeadingDistribution.even,
            ),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: Studio.muted),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Studio.inset,
        selectedColor: Studio.primary,
        disabledColor: Studio.inset.withValues(alpha: 0.5),
        labelStyle: Studio.mono(
          size: 10.5,
          color: Studio.text,
          weight: FontWeight.w700,
          height: 1,
        ),
        secondaryLabelStyle: Studio.mono(
          size: 10.5,
          color: Studio.onAccent(Studio.primary),
          weight: FontWeight.w700,
          height: 1,
        ),
        checkmarkColor: Studio.onAccent(Studio.primary),
        side: BorderSide(color: Studio.border),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Studio.primary,
          foregroundColor: Studio.onAccent(Studio.primary),
          shape: const StadiumBorder(),
          textStyle: Studio.mono(
            size: 12.5,
            weight: FontWeight.w700,
            letterSpacing: 0.8,
            height: 1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Studio.text,
          side: BorderSide(color: Studio.borderBright),
          shape: const StadiumBorder(),
          textStyle: Studio.mono(size: 11, weight: FontWeight.w700, height: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Studio.inset,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Studio.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Studio.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Studio.focus, width: 1.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Studio.surface,
        surfaceTintColor: Studio.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = _brightness;
    Studio.fontsEnabled = widget.useGoogleFonts;
    Studio.brightness = brightness;
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'morphnext studio',
      theme: _theme(),
      routerConfig: _router,
    );
  }
}

GoRouter _buildRouter({
  String? initialLocation,
  required bool loadLiveMetadata,
  required ValueChanged<Brightness> onBrightnessChanged,
}) => GoRouter(
  initialLocation: initialLocation,
  overridePlatformDefaultLocation: initialLocation != null,
  routes: <RouteBase>[
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => _LandingShell(
        navigationShell: navigationShell,
        loadLiveMetadata: loadLiveMetadata,
        onBrightnessChanged: onBrightnessChanged,
      ),
      branches: <StatefulShellBranch>[
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/',
              name: 'random',
              builder: (context, state) => const RandomShowcasePage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/playground',
              name: 'playground',
              builder: (context, state) => const MorphPlaygroundPage(),
            ),
          ],
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) => const _RouteErrorPage(),
);

class _LandingShell extends StatelessWidget {
  const _LandingShell({
    required this.navigationShell,
    required this.loadLiveMetadata,
    required this.onBrightnessChanged,
  });

  final StatefulNavigationShell navigationShell;
  final bool loadLiveMetadata;
  final ValueChanged<Brightness> onBrightnessChanged;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey<String>('landing-shell'),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            MorphnextTopBar(
              page: navigationShell.currentIndex,
              onPageChanged: _goBranch,
              loadLiveMetadata: loadLiveMetadata,
              brightness: Theme.of(context).brightness,
              onBrightnessChanged: onBrightnessChanged,
            ),
            Divider(height: 1, color: Studio.border),
            Expanded(
              child: SizedBox.expand(
                key: const ValueKey('shell_body_frame'),
                child: navigationShell,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RandomShowcasePage extends StatelessWidget {
  const RandomShowcasePage({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 600;
      final horizontalPadding = compact ? 16.0 : 28.0;
      final heroHeight = (constraints.maxHeight * (compact ? 0.58 : 0.66))
          .clamp(compact ? 360.0 : 420.0, compact ? 500.0 : 600.0);
      return ListView(
        key: const ValueKey<String>('random-page'),
        padding: EdgeInsets.zero,
        children: <Widget>[
          SizedBox(
            key: const ValueKey<String>('random-hero-viewport'),
            height: heroHeight,
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: EndlessMorphShowcase(),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: const MorphnextInstallBlock(),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              compact ? 54 : 72,
              horizontalPadding,
              0,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: const MorphBentoSection(),
              ),
            ),
          ),
          SizedBox(height: compact ? 44 : 64),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: const MorphnextFooter(),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      );
    },
  );
}

class _RouteErrorPage extends StatelessWidget {
  const _RouteErrorPage();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.explore_off_outlined, size: 48),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Studio.display(size: 32, weight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            StudioButton(
              onPressed: () => context.go('/'),
              child: const Text('Back to random'),
            ),
          ],
        ),
      ),
    ),
  );
}

class MorphPlaygroundPage extends StatefulWidget {
  const MorphPlaygroundPage({super.key});

  @override
  State<MorphPlaygroundPage> createState() => _MorphPlaygroundPageState();
}

class _MorphPlaygroundPageState extends State<MorphPlaygroundPage>
    with SingleTickerProviderStateMixin {
  static const _springChoices = <_SpringChoice>[
    (label: 'Smooth', spring: MorphSprings.smooth),
    (label: 'Snappy', spring: MorphSprings.snappy),
  ];

  static const _curveChoices = <({String label, Curve curve})>[
    (label: 'easeInOut', curve: Curves.easeInOut),
    (label: 'easeOutCubic', curve: Curves.easeOutCubic),
    (label: 'easeOutBack', curve: Curves.easeOutBack),
    (label: 'linear', curve: Curves.linear),
  ];

  static const _swatches = <({String label, Color? color})>[
    (label: 'Theme', color: null),
    (label: 'Blue', color: Color(0xFF7CACF8)),
    (label: 'Green', color: Color(0xFF6DD58C)),
    (label: 'Yellow', color: Color(0xFFFDD663)),
    (label: 'Red', color: Color(0xFFF28B82)),
    (label: 'Violet', color: Color(0xFFD7AEFB)),
  ];

  IconData _heroFrom = Icons.menu;
  IconData _heroTo = Icons.close;
  var _heroShowingTo = false;
  var _heroMotion = _HeroMotion.spring;
  var _heroSize = 184.0;
  var _heroProgress = 0.0;
  Color? _heroColor;

  // The spring is held as raw physics rather than as a preset, so every knob
  // SpringDescription exposes is reachable from the panel. The named choices
  // just seed these three values.
  var _springMass = MorphSprings.snappy.mass;
  var _springStiffness = MorphSprings.snappy.stiffness;
  var _springDamping = MorphSprings.snappy.damping;
  var _speed = 1.0;

  final _dice = math.Random();
  var _randomMode = false;
  var _shuffleAuto = false;
  var _shuffleInterval = const Duration(milliseconds: 1400);
  Timer? _shuffleTimer;
  Timer? _copyResetTimer;
  var _codeCopied = false;

  var _manualDuration = const Duration(milliseconds: 900);
  Curve _manualCurve = Curves.easeInOut;
  late final AnimationController _playback;

  /// Rescaling stiffness by the square of the speed and damping linearly is
  /// what keeps the spring's *shape* intact while stretching it in time — drop
  /// either factor and slowing it down also changes how much it overshoots.
  SpringDescription get _effectiveHeroSpring => SpringDescription(
    mass: _springMass,
    stiffness: _springStiffness * _speed * _speed,
    damping: _springDamping * _speed,
  );

  @override
  void initState() {
    super.initState();
    _playback = AnimationController(vsync: this, duration: _manualDuration)
      ..addListener(() {
        // Overshooting curves such as easeOutBack leave [0, 1], which both the
        // morph and the progress Slider reject.
        setState(() {
          _heroProgress = _manualCurve
              .transform(_playback.value)
              .clamp(0.0, 1.0);
        });
      });
  }

  @override
  void dispose() {
    _shuffleTimer?.cancel();
    _copyResetTimer?.cancel();
    _playback.dispose();
    super.dispose();
  }

  /// Random mode shuffles the *TO* endpoint rather than driving a separate
  /// preview: the picker keeps showing whatever was rolled, the icon can be
  /// grabbed and kept, and the stage needs no extra branch. Re-targeting mid
  /// flight is exactly what [AnimatedMorphIcon] is built to absorb, so a shuffle
  /// during a transition bends toward the new shape instead of snapping back.
  void _shuffleIcon() {
    final current = _heroShowingTo ? _heroTo : _heroFrom;
    IconData candidate;
    do {
      candidate = heroIconCatalog[_dice.nextInt(heroIconCatalog.length)].icon;
    } while (candidate == current && heroIconCatalog.length > 1);
    setState(() {
      _heroTo = candidate;
      _heroShowingTo = true;
      _heroProgress = 1;
    });
  }

  void _syncShuffleTimer() {
    _shuffleTimer?.cancel();
    if (_randomMode && _shuffleAuto) {
      _shuffleTimer = Timer.periodic(_shuffleInterval, (_) => _shuffleIcon());
    }
  }

  void _playManual() {
    _playback.duration = _manualDuration;
    if (_heroProgress >= 0.999) {
      _playback.value = 1;
      _playback.reverse();
    } else {
      _playback.value = _heroProgress;
      _playback.forward();
    }
  }

  void _applySpring(SpringDescription spring) {
    setState(() {
      _springMass = spring.mass;
      _springStiffness = spring.stiffness;
      _springDamping = spring.damping;
    });
  }

  bool _springMatches(SpringDescription spring) =>
      _springMass == spring.mass &&
      _springStiffness == spring.stiffness &&
      _springDamping == spring.damping;

  String _iconLabel(IconData icon) =>
      iconCatalogByIcon[icon]?.label ??
      'U+${icon.codePoint.toRadixString(16).toUpperCase()}';

  Future<void> _pickEndpoint({
    required bool from,
    required IconData current,
  }) async {
    final selected = await showIconBrowser(
      context,
      endpoint: from ? 'FROM' : 'TO',
      selected: current,
    );
    if (!mounted || selected == null) return;
    _selectEndpoint(from: from, icon: selected.icon);
  }

  void _selectEndpoint({required bool from, required IconData icon}) {
    setState(() {
      if (from) {
        _heroFrom = icon;
      } else {
        _heroTo = icon;
      }
      _heroShowingTo = false;
      _heroProgress = 0;
    });
  }

  void _swapEndpoints() {
    setState(() {
      final previousFrom = _heroFrom;
      _heroFrom = _heroTo;
      _heroTo = previousFrom;
      _heroShowingTo = false;
      _heroProgress = 0;
    });
  }

  void _setHeroMotion(_HeroMotion motion) {
    setState(() {
      _heroMotion = motion;
      if (motion == _HeroMotion.manual) {
        _heroProgress = _heroShowingTo ? 1 : 0;
      }
    });
    _syncShuffleTimer();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final horizontalPadding = constraints.maxWidth < 520 ? 16.0 : 28.0;
      final contentWidth = math.max(
        0.0,
        math.min(1080.0, constraints.maxWidth - horizontalPadding * 2),
      );
      final compact = constraints.maxWidth < 600;
      final brightness = Theme.of(context).brightness;

      return ListView(
        key: const ValueKey<String>('playground-page'),
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          constraints.maxWidth < 600 ? 32 : 48,
          horizontalPadding,
          40,
        ),
        children: <Widget>[
          KeyedSubtree(
            key: ValueKey<String>('playground-theme-${brightness.name}'),
            child: Center(
              child: SizedBox(
                width: contentWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Caps display, film voice: the playground's headline
                    // speaks the same way MORPH / EVERY / FLUTTER / ICONDATA
                    // do in act one of the preview.
                    Text(
                      'BUILD',
                      style: Studio.display(
                        size: compact ? 38 : 48,
                        weight: FontWeight.w800,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _hero(width: contentWidth),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: SizedBox(
              width: contentWidth,
              child: const MorphnextFooter(),
            ),
          ),
        ],
      );
    },
  );

  Widget _hero({required double width}) {
    final pair = (
      label: 'Custom',
      fromLabel: _iconLabel(_heroFrom),
      toLabel: _iconLabel(_heroTo),
      from: _heroFrom,
      to: _heroTo,
    );
    final target = _heroShowingTo ? pair.to : pair.from;
    final targetLabel = _heroShowingTo ? pair.fromLabel : pair.toLabel;

    return SizedBox(
      width: width,
      child: StudioPanel(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stage = _morphStage(pair: pair, target: target);
            final controls = _heroControls(targetLabel: targetLabel);

            if (constraints.maxWidth >= 720) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(flex: 5, child: stage),
                  const SizedBox(width: 32),
                  Expanded(flex: 4, child: controls),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[stage, const SizedBox(height: 24), controls],
            );
          },
        ),
      ),
    );
  }

  Widget _morphStage({required _MorphPair pair, required IconData target}) {
    final Widget preview = _heroMotion == _HeroMotion.spring
        ? AnimatedMorphIcon(
            // Keying on the endpoints deliberately rebuilds the widget when the
            // pair is re-picked. Rolling dice must NOT do that: a new key throws
            // away the morph state and the icon would snap to the next glyph
            // instead of animating into it, so shuffling holds one key and only
            // swaps [icon].
            key: _randomMode
                ? const ValueKey<String>('primary-morph-random')
                : ValueKey<String>(
                    'primary-morph-${pair.from.codePoint}-${pair.to.codePoint}',
                  ),
            icon: target,
            spring: _effectiveHeroSpring,
            size: _heroSize,
            color: _heroColor,
            semanticLabel: 'Primary morph preview',
          )
        : MorphIcon(
            key: ValueKey<String>(
              'primary-manual-${pair.from.codePoint}-${pair.to.codePoint}',
            ),
            from: pair.from,
            to: pair.to,
            progress: AlwaysStoppedAnimation<double>(_heroProgress),
            size: _heroSize,
            color: _heroColor,
            semanticLabel: 'Primary morph preview',
          );

    return SizedBox(
      key: const ValueKey<String>('primary-morph-stage'),
      height: math.max(240, _heroSize + 56),
      child: Center(child: preview),
    );
  }

  Widget _heroControls({required String targetLabel}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: _iconPicker(
              key: const ValueKey<String>('from-picker'),
              label: 'FROM',
              value: _heroFrom,
              from: true,
            ),
          ),
          IconButton(
            key: const ValueKey<String>('swap-icons'),
            tooltip: 'Swap endpoints',
            onPressed: _swapEndpoints,
            icon: const Icon(Icons.swap_horiz),
          ),
          Expanded(
            child: _iconPicker(
              key: const ValueKey<String>('to-picker'),
              label: 'TO',
              value: _heroTo,
              from: false,
            ),
          ),
        ],
      ),
      // Random belongs here, next to the endpoints, because that is what it
      // changes — which icon comes next. Spring vs Manual is a different axis
      // entirely (what drives the progress), so folding random into that
      // selector made the two read as alternatives when they in fact compose.
      const SizedBox(height: 14),
      _randomControls(),
      const SizedBox(height: 22),
      _heroMotionControls(targetLabel: targetLabel),
    ],
  );

  /// The playground's primary action: a single oversized transport button
  /// sitting under the stage, where the eye already is.
  ///
  /// It carries no label — the glyph morphs between play and replay using the
  /// package itself, so the control demonstrates the thing it drives. The
  /// wording lives in the tooltip and the semantic label instead.
  Widget _launchButton({required String targetLabel}) {
    final accent = _heroColor ?? Studio.primary;
    final onAccent = Studio.onAccent(accent);
    final spring = _heroMotion == _HeroMotion.spring;
    final settled = spring ? _heroShowingTo : _heroProgress >= 0.999;
    final key = spring
        ? const ValueKey<String>('implicit-toggle')
        : const ValueKey<String>('manual-playback');
    final label = spring
        ? (_heroShowingTo
              ? 'Morph back to $targetLabel'
              : 'Morph to $targetLabel')
        : (settled ? 'Play in reverse' : 'Play morph');
    final action = spring
        ? () => setState(() => _heroShowingTo = !_heroShowingTo)
        : _playManual;
    return Tooltip(
      message: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: accent.withValues(alpha: 0.26), width: 1.4),
        ),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: SizedBox.square(
            dimension: 54,
            child: FilledButton(
              key: key,
              onPressed: action,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: onAccent,
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
                elevation: 0,
              ),
              // Reverse is the same glyph turned around rather than a second
              // icon, so both states stay identical in weight.
              child: Semantics(
                label: label,
                child: AnimatedRotation(
                  turns: settled ? 0.5 : 0,
                  duration: const Duration(milliseconds: 340),
                  curve: Curves.easeOutBack,
                  child: CustomPaint(
                    size: const Size.square(22),
                    painter: _PlayGlyphPainter(color: onAccent),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A labelled slider with a live readout. Every tunable on this page goes
  /// through it so the whole panel reads as one control surface.
  Widget _tuner({
    required String label,
    required String readout,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    Key? sliderKey,
    int? divisions,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            label,
            style: Studio.mono(
              size: 10,
              color: Studio.muted,
              weight: FontWeight.w700,
              letterSpacing: 0.9,
            ),
          ),
          Text(
            readout,
            style: Studio.mono(
              size: 10.5,
              color: _heroColor ?? Studio.primary,
              weight: FontWeight.w700,
            ),
          ),
        ],
      ),
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 3,
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          activeTrackColor: _heroColor ?? Studio.primary,
          thumbColor: _heroColor ?? Studio.primary,
        ),
        child: Slider(
          key: sliderKey,
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ),
    ],
  );

  /// Random target controls, parked directly under the endpoint pickers.
  ///
  /// [_randomMode] arms it, the dice rolls one new target on demand, and auto
  /// keeps rolling. The second row is always mounted so toggling either option
  /// never changes the height of the control panel.
  Widget _randomControls() {
    final accent = _heroColor ?? Studio.primary;
    final autoEnabled = _randomMode;
    final intervalEnabled = _randomMode && _shuffleAuto;
    return Column(
      key: const ValueKey<String>('random-controls'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'RANDOM TARGET',
                style: Studio.mono(
                  size: 10,
                  color: _randomMode ? accent : Studio.muted,
                  weight: FontWeight.w700,
                  letterSpacing: 0.9,
                ),
              ),
            ),
            IconButton(
              key: const ValueKey<String>('shuffle-icon'),
              tooltip: 'Roll a new target icon',
              onPressed: _randomMode ? _shuffleIcon : null,
              icon: const Icon(Icons.casino_rounded),
              color: accent,
            ),
            Switch.adaptive(
              key: const ValueKey<String>('random-mode'),
              value: _randomMode,
              activeTrackColor: accent,
              thumbColor: WidgetStatePropertyAll(Studio.onAccent(accent)),
              // Arming only swaps the preview over to its stable key; it
              // deliberately does not roll. Rolling in the same frame as the
              // key change would land the first icon without a transition.
              onChanged: (value) {
                setState(() {
                  _randomMode = value;
                  if (!value) _shuffleAuto = false;
                });
                _syncShuffleTimer();
              },
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            Text(
              'AUTO',
              style: Studio.mono(
                size: 9.5,
                color: autoEnabled ? Studio.muted : Studio.faint,
                weight: FontWeight.w700,
                letterSpacing: 0.9,
              ),
            ),
            const SizedBox(width: 6),
            Transform.scale(
              scale: 0.82,
              child: Switch.adaptive(
                key: const ValueKey<String>('shuffle-auto'),
                value: autoEnabled && _shuffleAuto,
                activeTrackColor: accent,
                thumbColor: WidgetStatePropertyAll(Studio.onAccent(accent)),
                onChanged: autoEnabled
                    ? (value) {
                        setState(() => _shuffleAuto = value);
                        _syncShuffleTimer();
                      }
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        'INTERVAL',
                        style: Studio.mono(
                          size: 9.5,
                          color: intervalEnabled ? Studio.muted : Studio.faint,
                          weight: FontWeight.w700,
                          letterSpacing: 0.9,
                        ),
                      ),
                      Text(
                        '${_shuffleInterval.inMilliseconds} ms',
                        style: Studio.mono(
                          size: 9.5,
                          color: intervalEnabled ? accent : Studio.faint,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 28,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 12,
                        ),
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                          disabledThumbRadius: 6,
                        ),
                        activeTrackColor: accent,
                        thumbColor: accent,
                      ),
                      child: Slider(
                        key: const ValueKey<String>('shuffle-interval'),
                        value: _shuffleInterval.inMilliseconds.toDouble(),
                        min: 300,
                        max: 4000,
                        onChanged: intervalEnabled
                            ? (value) {
                                setState(
                                  () => _shuffleInterval = Duration(
                                    milliseconds: value.round(),
                                  ),
                                );
                                _syncShuffleTimer();
                              }
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Colour picker as bare dots rather than labelled chips: six chips wrapped
  /// onto two rows and read as a form, where the choice is really a palette.
  ///
  /// The name moves to the row's readout — same label/value rhythm as the
  /// sliders above it — and to each dot's tooltip, so nothing is lost.
  Widget _swatchRow() {
    final selected = _swatches.firstWhere(
      (swatch) => swatch.color == _heroColor,
      orElse: () => _swatches.first,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              'COLOR',
              style: Studio.mono(
                size: 10,
                color: Studio.muted,
                weight: FontWeight.w700,
                letterSpacing: 0.9,
              ),
            ),
            Text(
              selected.label,
              style: Studio.mono(
                size: 10.5,
                color: _heroColor ?? Studio.primary,
                weight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            for (final swatch in _swatches) ...<Widget>[
              _swatch(label: swatch.label, color: swatch.color),
              if (swatch != _swatches.last) const SizedBox(width: 10),
            ],
          ],
        ),
      ],
    );
  }

  Widget _swatch({required String label, required Color? color}) {
    final chosen = _heroColor == color;
    // The theme entry has no colour of its own, so it shows the tone the icon
    // actually inherits when none is set.
    final dot = color ?? Studio.text;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: chosen,
        label: '$label icon color',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            key: ValueKey<String>('color-${label.toLowerCase()}'),
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _heroColor = color),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: chosen ? dot : Studio.border,
                  width: chosen ? 2 : 1,
                ),
              ),
              // Selecting pulls the dot in a little, opening a gap inside the
              // ring — that gap is what reads as "selected" at a glance.
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  width: chosen ? 18 : 24,
                  height: chosen ? 18 : 24,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: dot),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: Studio.mono(
        size: 9.5,
        color: Studio.faint,
        weight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
    ),
  );

  Widget _heroMotionControls({required String targetLabel}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      // Transport row: pick the mode and fire it from the same line, so the
      // trigger sits with the thing it triggers instead of drifting off on its
      // own somewhere in the panel.
      Row(
        children: <Widget>[
          Expanded(
            child: SegmentedButton<_HeroMotion>(
              key: const ValueKey<String>('hero-motion'),
              segments: const <ButtonSegment<_HeroMotion>>[
                ButtonSegment<_HeroMotion>(
                  value: _HeroMotion.spring,
                  label: Text('Spring'),
                ),
                ButtonSegment<_HeroMotion>(
                  value: _HeroMotion.manual,
                  label: Text('Manual'),
                ),
              ],
              selected: <_HeroMotion>{_heroMotion},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  _setHeroMotion(selection.single),
            ),
          ),
          const SizedBox(width: 14),
          _launchButton(targetLabel: targetLabel),
        ],
      ),
      const SizedBox(height: 22),
      _sectionLabel('APPEARANCE'),
      _tuner(
        label: 'SIZE',
        readout: '${_heroSize.round()} px',
        value: _heroSize,
        min: 32,
        max: 384,
        sliderKey: const ValueKey<String>('hero-size'),
        onChanged: (value) => setState(() => _heroSize = value),
      ),
      const SizedBox(height: 10),
      _swatchRow(),
      const SizedBox(height: 24),
      if (_heroMotion == _HeroMotion.spring) ...<Widget>[
        _sectionLabel('SPRING PHYSICS'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final choice in _springChoices)
              ChoiceChip(
                key: ValueKey<String>('spring-${choice.label.toLowerCase()}'),
                label: Text(choice.label),
                selected: _springMatches(choice.spring),
                showCheckmark: false,
                onSelected: (_) => _applySpring(choice.spring),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _tuner(
          label: 'MASS',
          readout: _springMass.toStringAsFixed(2),
          value: _springMass,
          min: 0.2,
          max: 4,
          sliderKey: const ValueKey<String>('spring-mass'),
          onChanged: (value) => setState(() => _springMass = value),
        ),
        _tuner(
          label: 'STIFFNESS',
          readout: _springStiffness.round().toString(),
          value: _springStiffness,
          min: 20,
          max: 900,
          sliderKey: const ValueKey<String>('spring-stiffness'),
          onChanged: (value) => setState(() => _springStiffness = value),
        ),
        _tuner(
          label: 'DAMPING',
          readout: _springDamping.toStringAsFixed(1),
          value: _springDamping,
          min: 2,
          max: 90,
          sliderKey: const ValueKey<String>('spring-damping'),
          onChanged: (value) => setState(() => _springDamping = value),
        ),
        _tuner(
          label: 'SPEED',
          readout: '${_speed.toStringAsFixed(2)}×',
          value: _speed,
          min: 0.1,
          max: 2,
          sliderKey: const ValueKey<String>('hero-speed'),
          onChanged: (value) => setState(() => _speed = value),
        ),
        const SizedBox(height: 14),
        _codeBlock(_springCode),
      ] else ...<Widget>[
        _sectionLabel('MANUAL PROGRESS'),
        _tuner(
          label: 'PROGRESS',
          readout: '${(_heroProgress * 100).round()}%',
          value: _heroProgress,
          min: 0,
          max: 1,
          sliderKey: const ValueKey<String>('hero-progress'),
          onChanged: (value) {
            _playback.stop();
            setState(() => _heroProgress = value);
          },
        ),
        _tuner(
          label: 'DURATION',
          readout: '${_manualDuration.inMilliseconds} ms',
          value: _manualDuration.inMilliseconds.toDouble(),
          min: 120,
          max: 3000,
          sliderKey: const ValueKey<String>('manual-duration'),
          onChanged: (value) => setState(
            () => _manualDuration = Duration(milliseconds: value.round()),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final choice in _curveChoices)
              ChoiceChip(
                key: ValueKey<String>('curve-${choice.label}'),
                label: Text(choice.label),
                selected: _manualCurve == choice.curve,
                showCheckmark: false,
                onSelected: (_) => setState(() => _manualCurve = choice.curve),
              ),
          ],
        ),
        const SizedBox(height: 14),
        _codeBlock(_manualCode),
      ],
    ],
  );

  /// Mirrors the current settings back as the code that would produce them, so
  /// a configuration found by ear can be copied straight into a project.
  ///
  /// Both modes end on one of these. Beyond being useful, it keeps the panel
  /// the same shape either way: without it the manual branch is several
  /// controls shorter and the card visibly collapses when the mode flips.
  String get _springCode {
    final spring = _effectiveHeroSpring;
    return 'AnimatedMorphIcon(\n'
        '  icon: ${_iconCode(_heroShowingTo ? _heroTo : _heroFrom)},\n'
        '  size: ${_heroSize.round()},\n'
        '  spring: SpringDescription(\n'
        '    mass: ${spring.mass.toStringAsFixed(2)},\n'
        '    stiffness: ${spring.stiffness.toStringAsFixed(1)},\n'
        '    damping: ${spring.damping.toStringAsFixed(1)},\n'
        '  ),\n'
        ')';
  }

  String get _manualCode {
    final curve = _curveChoices
        .firstWhere(
          (choice) => choice.curve == _manualCurve,
          orElse: () => _curveChoices.first,
        )
        .label;
    return 'MorphIcon(\n'
        '  from: ${_iconCode(_heroFrom)},\n'
        '  to: ${_iconCode(_heroTo)},\n'
        '  size: ${_heroSize.round()},\n'
        '  progress: CurvedAnimation(\n'
        '    parent: controller, // ${_manualDuration.inMilliseconds} ms\n'
        '    curve: Curves.$curve,\n'
        '  ),\n'
        ')';
  }

  String _iconCode(IconData icon) {
    final entry = iconCatalogByIcon[icon];
    if (entry == null) {
      final family = icon.fontFamily;
      final package = icon.fontPackage;
      final code = StringBuffer(
        'const IconData(0x${icon.codePoint.toRadixString(16)}',
      );
      if (family != null) code.write(", fontFamily: '$family'");
      if (package != null) code.write(", fontPackage: '$package'");
      return '${code.toString()})';
    }

    final identifier = switch (entry.family) {
      IconCatalogFamily.material => 'Icons.${entry.name}',
      IconCatalogFamily.cupertino => 'CupertinoIcons.${entry.name}',
      IconCatalogFamily.fontAwesome =>
        'FontAwesomeIcons.${_lowerCamel(entry.name)}',
      IconCatalogFamily.lucide => 'LucideIcons.${_lowerCamel(entry.name)}',
      IconCatalogFamily.tabler => 'TablerIcons.${entry.name}',
      IconCatalogFamily.remix => 'RemixIcons.${entry.name}',
    };
    return identifier;
  }

  String _lowerCamel(String value) {
    final parts = value.split('_');
    return parts.first +
        parts.skip(1).map((part) {
          if (part.isEmpty) return '';
          return '${part[0].toUpperCase()}${part.substring(1)}';
        }).join();
  }

  Future<void> _copyCode(String code) async {
    _copyResetTimer?.cancel();
    setState(() => _codeCopied = true);
    _copyResetTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _codeCopied = false);
    });
    await Clipboard.setData(ClipboardData(text: code));
  }

  Widget _codeBlock(String code) {
    final copied = _codeCopied;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: Studio.inset,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Studio.border),
      ),
      child: Stack(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 38),
            child: SelectableText(
              code,
              key: const ValueKey<String>('playground-code'),
              style: Studio.mono(size: 10.5, color: Studio.muted, height: 1.5),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Tooltip(
              message: copied ? 'Copied' : 'Copy code',
              child: IconButton(
                key: const ValueKey<String>('playground-code-copy'),
                onPressed: () => _copyCode(code),
                icon: AnimatedMorphIcon(
                  icon: copied ? Icons.check_rounded : Icons.content_copy,
                  size: 17,
                  color: Studio.muted,
                  spring: MorphSprings.snappy,
                  applyTextScaling: false,
                  semanticLabel: copied ? 'Code copied' : 'Copy code',
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                splashRadius: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconPicker({
    required Key key,
    required String label,
    required IconData value,
    required bool from,
  }) {
    final entry = iconCatalogByIcon[value];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Studio.mono(
            size: 9.5,
            color: Studio.faint,
            weight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            key: key,
            onPressed: () => _pickEndpoint(from: from, current: value),
            // A field, not an action: the pickers keep a soft rectangle while
            // every true action on the page wears the film's pill.
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.all(12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(value, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        entry?.label ?? _iconLabel(value),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        entry?.family.label ?? 'Icon font',
                        style: Studio.mono(size: 9, color: Studio.faint),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.expand_more),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The play glyph: an equilateral triangle whose corners are trimmed back to
/// real arcs.
///
/// Drawing it rather than reaching for a font icon keeps the corner radius and
/// the optical centring under our control at any diameter, and lets the reverse
/// state be the same shape rotated instead of a second, heavier glyph.
final class _PlayGlyphPainter extends CustomPainter {
  const _PlayGlyphPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide;
    if (unit <= 0) {
      return;
    }

    final base = unit;
    final reach = base * 0.88;
    // A triangle's centroid sits a third of the way back from its apex, so
    // centring the bounding box would leave the glyph looking shifted left.
    final centre = Offset(size.width / 2 + reach * 0.08, size.height / 2);
    final apex = Offset(centre.dx + reach / 2, centre.dy);
    final top = Offset(centre.dx - reach / 2, centre.dy - base / 2);
    final bottom = Offset(centre.dx - reach / 2, centre.dy + base / 2);

    canvas.drawPath(
      _roundedTriangle(top, apex, bottom, unit * 0.16),
      Paint()..color = color,
    );
  }

  /// Corners are trimmed along both adjoining edges by `r / tan(θ/2)`, which is
  /// the distance at which a circle of radius `r` sits tangent to both — the
  /// arc then joins the two trim points without a kink.
  static Path _roundedTriangle(Offset a, Offset b, Offset c, double radius) {
    final points = <Offset>[a, b, c];
    final path = Path();
    for (var i = 0; i < 3; i++) {
      final previous = points[(i + 2) % 3];
      final current = points[i];
      final next = points[(i + 1) % 3];
      final toPrevious = previous - current;
      final toNext = next - current;
      final directionPrevious = toPrevious / toPrevious.distance;
      final directionNext = toNext / toNext.distance;
      final cosine =
          (directionPrevious.dx * directionNext.dx +
                  directionPrevious.dy * directionNext.dy)
              .clamp(-1.0, 1.0);
      final trim = math.min(
        radius / math.tan(math.acos(cosine) / 2),
        math.min(toPrevious.distance, toNext.distance) / 2,
      );
      final start = current + directionPrevious * trim;
      final end = current + directionNext * trim;
      if (i == 0) {
        path.moveTo(start.dx, start.dy);
      } else {
        path.lineTo(start.dx, start.dy);
      }
      path.arcToPoint(end, radius: Radius.circular(radius));
    }
    return path..close();
  }

  @override
  bool shouldRepaint(covariant _PlayGlyphPainter oldDelegate) =>
      color != oldDelegate.color;
}
