import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The palette, typography, and controls shared with the reel_text studio.
abstract final class Studio {
  static bool fontsEnabled = false;

  static Brightness _brightness = Brightness.dark;
  static ColorScheme? _cachedScheme;
  static _StudioPalette? _cachedPalette;
  static _StudioAccentPalette? _cachedAccents;

  static Brightness get brightness => _brightness;

  static set brightness(Brightness value) {
    if (_brightness == value) return;
    _brightness = value;
    _cachedScheme = null;
    _cachedPalette = null;
    _cachedAccents = null;
  }

  static bool get isLight => _brightness == Brightness.light;

  static ColorScheme get scheme =>
      _cachedScheme ??= _GoogleStudioScheme.fromBrightness(_brightness);

  static _StudioPalette get _palette =>
      _cachedPalette ??= _StudioPalette.fromScheme(scheme);

  static Color get transparent => Colors.transparent;
  static Color get white => _GoogleNeutral.white;
  static Color get black => _GoogleNeutral.black;
  static Color get background => _palette.background;
  static Color get surface => _palette.surface;
  static Color get surfaceRaised => _palette.surfaceRaised;
  static Color get inset => _palette.inset;
  static Color get border => _palette.border;
  static Color get borderBright => _palette.borderBright;
  static Color get text => _palette.text;
  static Color get muted => _palette.muted;
  static Color get faint => _palette.faint;

  static _StudioAccentPalette get _accents =>
      _cachedAccents ??= _StudioAccentPalette.fromScheme(scheme);

  static Color get primary => _accents.blue;
  static Color get success => _accents.green;
  static Color get warning => _accents.yellow;
  static Color get danger => _accents.red;
  static Color get info => _accents.cyan;
  static Color get violet => _accents.violet;
  static Color get focus => primary;

  static Color tone(Color accent) => accent;

  static Color onAccent(Color accent) {
    final darkInk = _GoogleNeutral.ink;
    final lightInk = _GoogleNeutral.white;
    return _contrastRatio(accent, lightInk) >= _contrastRatio(accent, darkInk)
        ? lightInk
        : darkInk;
  }

  static Color accentBorder(Color accent, {double? alpha}) {
    return tone(accent).withValues(alpha: alpha ?? (isLight ? 0.36 : 0.45));
  }

  static Color accentWash(Color accent, {double? alpha}) {
    return tone(accent).withValues(alpha: alpha ?? (isLight ? 0.075 : 0.08));
  }

  static double _contrastRatio(Color a, Color b) {
    final aLum = a.computeLuminance();
    final bLum = b.computeLuminance();
    final lighter = math.max(aLum, bLum);
    final darker = math.min(aLum, bLum);
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Display type inherits the preview film's voice: Instrument Sans at w800
  /// with tracking pulled in proportionally (-0.042 em, the ratio the film
  /// uses at every size). Pass [letterSpacing] only to opt out.
  static TextStyle display({
    double size = 64,
    Color? color,
    double height = 1.0,
    double? letterSpacing,
    FontWeight weight = FontWeight.w800,
  }) {
    final style = TextStyle(
      color: color ?? text,
      fontSize: size,
      height: height,
      letterSpacing: letterSpacing ?? size * -0.042,
      fontWeight: weight,
      leadingDistribution: TextLeadingDistribution.even,
    );
    return fontsEnabled ? GoogleFonts.instrumentSans(textStyle: style) : style;
  }

  static TextStyle mono({
    double size = 12,
    Color? color,
    FontWeight weight = FontWeight.w400,
    double letterSpacing = 0,
    double height = 1.4,
  }) {
    final style = TextStyle(
      color: color ?? muted,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      height: height,
      // Split any leading the height multiplier adds evenly above and below
      // the glyphs. Flutter's default splits it in the font's ascent:descent
      // ratio, which parks single-line labels visibly off the centre of
      // whatever control they sit in.
      leadingDistribution: TextLeadingDistribution.even,
      fontFamilyFallback: const ['Menlo', 'Consolas', 'monospace'],
    );
    return fontsEnabled ? GoogleFonts.jetBrainsMono(textStyle: style) : style;
  }

  static TextStyle buttonLabel({required Color color}) => mono(
    size: 12,
    color: color,
    weight: FontWeight.w700,
    letterSpacing: 0.4,
    height: 1,
  );

  static TextStyle body({
    double size = 13.5,
    Color? color,
    double height = 1.55,
    FontWeight weight = FontWeight.w400,
  }) {
    return TextStyle(
      color: color ?? muted,
      fontSize: size,
      height: height,
      fontWeight: weight,
      leadingDistribution: TextLeadingDistribution.even,
    );
  }
}

class _StudioPalette {
  const _StudioPalette({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.inset,
    required this.border,
    required this.borderBright,
    required this.text,
    required this.muted,
    required this.faint,
  });

  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color inset;
  final Color border;
  final Color borderBright;
  final Color text;
  final Color muted;
  final Color faint;

  factory _StudioPalette.fromScheme(ColorScheme scheme) => _StudioPalette(
    background: scheme.surface,
    surface: scheme.surfaceContainerLowest,
    surfaceRaised: scheme.surfaceContainerLow,
    inset: scheme.surfaceContainer,
    border: scheme.outlineVariant,
    borderBright: scheme.outline,
    text: scheme.onSurface,
    muted: scheme.onSurfaceVariant,
    faint: _GoogleNeutral.grey500,
  );
}

class _StudioAccentPalette {
  const _StudioAccentPalette({
    required this.blue,
    required this.green,
    required this.yellow,
    required this.red,
    required this.cyan,
    required this.violet,
  });

  final Color blue;
  final Color green;
  final Color yellow;
  final Color red;
  final Color cyan;
  final Color violet;

  factory _StudioAccentPalette.fromScheme(ColorScheme scheme) =>
      _StudioAccentPalette(
        blue: scheme.primary,
        green: _GoogleStudioScheme.isLight(scheme)
            ? _GoogleAccent.green600
            : scheme.secondary,
        yellow: _GoogleStudioScheme.isLight(scheme)
            ? _GoogleAccent.yellow700
            : _GoogleAccent.yellow200,
        red: scheme.error,
        cyan: _GoogleStudioScheme.isLight(scheme)
            ? _GoogleAccent.blue600
            : _GoogleAccent.blue200,
        violet: scheme.tertiary,
      );
}

abstract final class _GoogleStudioScheme {
  static bool isLight(ColorScheme scheme) =>
      scheme.brightness == Brightness.light;

  static ColorScheme fromBrightness(Brightness brightness) {
    final light = brightness == Brightness.light;
    final base = ColorScheme.fromSeed(
      seedColor: _GoogleAccent.blue600,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );

    return base.copyWith(
      primary: light ? _GoogleAccent.blue600 : _GoogleAccent.blue200,
      onPrimary: light ? _GoogleNeutral.white : _GoogleNeutral.ink,
      primaryContainer: light ? _GoogleAccent.blue50 : _GoogleAccent.blue900,
      onPrimaryContainer: light ? _GoogleAccent.blue900 : _GoogleAccent.blue50,
      secondary: light ? _GoogleAccent.green500 : _GoogleAccent.green200,
      onSecondary: _GoogleNeutral.ink,
      secondaryContainer: light
          ? _GoogleAccent.green50
          : _GoogleAccent.green900,
      onSecondaryContainer: light
          ? _GoogleAccent.green900
          : _GoogleAccent.green50,
      tertiary: light ? _GoogleAccent.purple600 : _GoogleAccent.purple200,
      onTertiary: light ? _GoogleNeutral.white : _GoogleNeutral.ink,
      tertiaryContainer: light
          ? _GoogleAccent.purple50
          : _GoogleAccent.purple900,
      onTertiaryContainer: light
          ? _GoogleAccent.purple900
          : _GoogleAccent.purple50,
      error: light ? _GoogleAccent.red600 : _GoogleAccent.red200,
      onError: light ? _GoogleNeutral.white : _GoogleNeutral.ink,
      errorContainer: light ? _GoogleAccent.red50 : _GoogleAccent.red900,
      onErrorContainer: light ? _GoogleAccent.red900 : _GoogleAccent.red50,
      surface: light
          ? _GoogleNeutral.lightBackground
          : _GoogleNeutral.darkBackground,
      surfaceDim: light ? _GoogleNeutral.lightGrey : _GoogleNeutral.black,
      surfaceBright: light ? _GoogleNeutral.white : _GoogleNeutral.grey800,
      surfaceContainerLowest: light
          ? _GoogleNeutral.paper
          : _GoogleNeutral.darkSurfaceLowest,
      surfaceContainerLow: light
          ? _GoogleNeutral.lightGrey
          : _GoogleNeutral.darkSurface,
      surfaceContainer: light
          ? _GoogleNeutral.lightInset
          : _GoogleNeutral.darkInset,
      surfaceContainerHigh: light
          ? _GoogleNeutral.border
          : _GoogleNeutral.darkInset,
      surfaceContainerHighest: light
          ? _GoogleNeutral.borderStrong
          : _GoogleNeutral.grey800,
      onSurface: light ? _GoogleNeutral.ink : _GoogleNeutral.paper,
      onSurfaceVariant: light ? _GoogleNeutral.grey700 : _GoogleNeutral.grey500,
      outline: light
          ? _GoogleNeutral.borderStrong
          : _GoogleNeutral.darkBorderBright,
      outlineVariant: light ? _GoogleNeutral.border : _GoogleNeutral.darkBorder,
      inverseSurface: light ? _GoogleNeutral.ink : _GoogleNeutral.lightGrey,
      onInverseSurface: light ? _GoogleNeutral.white : _GoogleNeutral.ink,
      inversePrimary: light ? _GoogleAccent.blue200 : _GoogleAccent.blue600,
      shadow: _GoogleNeutral.black,
      scrim: _GoogleNeutral.black,
      surfaceTint: light ? _GoogleAccent.blue600 : _GoogleAccent.blue200,
    );
  }
}

abstract final class _GoogleAccent {
  static const blue50 = Color(0xffd2e3fc);
  static const blue200 = Color(0xff8ab4f8);
  static const blue600 = Color(0xff1a73e8);
  static const blue900 = Color(0xff174ea6);
  static const green50 = Color(0xffceead6);
  static const green200 = Color(0xff81c995);
  static const green500 = Color(0xff34a853);
  static const green600 = Color(0xff188038);
  static const green900 = Color(0xff0d652d);
  static const yellow200 = Color(0xfffdd663);
  static const yellow700 = Color(0xff9a6700);
  static const red50 = Color(0xfffad2cf);
  static const red200 = Color(0xfff28b82);
  static const red600 = Color(0xffd93025);
  static const red900 = Color(0xffa50e0e);
  static const purple50 = Color(0xfff3e8fd);
  static const purple200 = Color(0xffd7aefb);
  static const purple600 = Color(0xff9334e6);
  static const purple900 = Color(0xff681da8);
}

abstract final class _GoogleNeutral {
  static const white = Color(0xffffffff);
  static const black = Color(0xff202124);
  static const ink = Color(0xff202124);
  static const grey500 = Color(0xff9aa0a6);
  static const grey700 = Color(0xff5f6368);
  static const grey800 = Color(0xff3c4043);
  // The two grounds of the preview film: everything light sits on paper,
  // everything dark sits on night. Surfaces do not stack — panels share the
  // ground and are separated by hairlines alone, the way the film stages its
  // acts on a single flat colour.
  static const paper = Color(0xfff8f9fa);
  static const night = Color(0xff17181a);
  static const lightBackground = paper;
  static const lightGrey = Color(0xfff1f3f4);
  static const lightInset = Color(0xfff1f3f4);
  static const border = Color(0xffdadce0);
  static const borderStrong = Color(0xffc0c2c5);
  static const darkBackground = night;
  static const darkSurfaceLowest = night;
  static const darkSurface = Color(0xff202124);
  static const darkInset = Color(0xff24262b);
  static const darkBorder = Color(0xff2e3136);
  static const darkBorderBright = Color(0xff43474e);
}

class StudioPanel extends StatefulWidget {
  const StudioPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;

  @override
  State<StudioPanel> createState() => _StudioPanelState();
}

class _StudioPanelState extends State<StudioPanel> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Theme.of(context).brightness;
    const radius = 20.0;
    final color = widget.color ?? Studio.surface;
    final borderColor = widget.borderColor ?? Studio.border;
    // Flat, like every surface in the preview film: panels share the page's
    // ground and are drawn by their hairline alone — no gradients, no
    // shadows, no lift. Hover only wakes the hairline up a little.
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: _isHovered ? Studio.borderBright : borderColor,
          ),
        ),
        child: Padding(padding: widget.padding, child: widget.child),
      ),
    );
  }
}

class StudioCaption extends StatelessWidget {
  const StudioCaption(this.label, {super.key, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Studio.mono(
        size: 10.5,
        color: color ?? Studio.muted,
        weight: FontWeight.w700,
        letterSpacing: 2.6,
      ),
    );
  }
}

class StudioChip extends StatelessWidget {
  const StudioChip(this.label, {super.key, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? Studio.muted;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          label,
          style: Studio.mono(
            size: 10.5,
            color: color,
            weight: FontWeight.w700,
            letterSpacing: 1.2,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class StudioButton extends StatelessWidget {
  const StudioButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.accent,
    this.filled = true,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;
  final Color? accent;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final accent = this.accent ?? Studio.primary;
    final accentText = Studio.tone(accent);
    final onAccent = Studio.onAccent(accent);
    final textStyle = Studio.buttonLabel(color: filled ? onAccent : accentText);
    // Every action is a pill — the same silhouette as the film's
    // `flutter pub add morphnext` lockup capsule.
    final style = filled
        ? FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: onAccent,
            textStyle: textStyle,
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          )
        : OutlinedButton.styleFrom(
            foregroundColor: accentText,
            side: BorderSide(color: Studio.accentBorder(accent)),
            textStyle: textStyle,
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          );
    if (icon == null) {
      return filled
          ? FilledButton(onPressed: onPressed, style: style, child: child)
          : OutlinedButton(onPressed: onPressed, style: style, child: child);
    }
    return filled
        ? FilledButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon, size: 16),
            label: child,
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon, size: 16),
            label: child,
          );
  }
}
