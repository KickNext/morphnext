# morphnext

**Morph into what’s next.**

morphnext turns bundled Flutter `IconData` glyphs into interruptible,
spring-driven vector morphs without requiring per-pair animation assets.

![morphnext showcase](https://raw.githubusercontent.com/KickNext/morphnext/main/assets/morphnext_hero_720p_60fps_full_cycle.webp)

## Install

```console
flutter pub add morphnext
```

Requires Dart `>=3.9.0` and Flutter `>=3.32.0`.

## Implicit morph

Change `icon`; `AnimatedMorphIcon` starts from the shape currently on screen,
even when a new target interrupts an active transition.

```dart
import 'package:flutter/material.dart';
import 'package:morphnext/morphnext.dart';

IconButton(
  onPressed: () => setState(() => open = !open),
  icon: AnimatedMorphIcon(
    icon: open ? Icons.close : Icons.menu,
    semanticLabel: open ? 'Close menu' : 'Open menu',
  ),
)
```

Use `onEnd` when the next action must wait for the spring to finish and the
target to settle on its final vector frame.

`AnimatedMorphIcon` uses `MorphSprings.snappy` by default. Select
`MorphSprings.smooth` for a critically damped transition, or pass Flutter's
`SpringDescription` directly for custom physics.

The widgets accept the same visual font controls as Flutter's `Icon`:
`fill`, `weight`, `grade`, `opticalSize`, `shadows`, `blendMode`, and
`fontWeight`. Values not supplied directly are inherited from `IconTheme`.

## Controlled morph

Use any `Animation<double>` for gestures, scrolling, or a timeline. Progress is
clamped to `0`–`1`.

```dart
MorphIcon(
  from: Icons.favorite_border,
  to: Icons.favorite,
  progress: controller,
  size: 32,
  color: Colors.red,
  semanticLabel: 'Favorite',
)
```

## Font compatibility

There is no `fontAsset` argument. `IconData` identifies a code point, font
family, package, and fallback families—not an asset path. morphnext uses those
fields and Flutter's font manifest to resolve fonts bundled through
`pubspec.yaml`.

If a font is loaded only at runtime, missing, malformed, or unsupported,
morphnext preserves the widget layout and displays regular Flutter icons
instead. The UI remains usable, but that transition is not a continuous vector
morph.

## Flutter conventions

`size`, `color`, opacity, variable axes, shadows, optional text scaling, and
directionality follow `IconTheme`, `MediaQuery`, and `Directionality` like
Flutter's `Icon`.
`matchTextDirection` is honored in RTL layouts. Set `semanticLabel` for one
semantic image node; leave it null for a decorative icon. When
`MediaQuery.disableAnimations` is true, `AnimatedMorphIcon` settles immediately.

## Performance and caching

Fonts and morph plans are loaded lazily and cached with bounded memory use.
Animation repaints directly without rebuilding the widget on every frame.

## Limitations

morphnext preserves filled contour topology and keeps holes open, but arbitrary
icon pairs can still produce an artistically surprising intermediate shape.
The renderer is monochrome and accepts bundled font-backed `IconData`; it does
not morph arbitrary Flutter `Path` objects or SVG artwork.

## Examples

`example/example.dart` is the compact pub.dev example. The app in
`example/lib/main.dart` powers the GitHub Pages showcase and interactive
playground.

## License and attribution

morphnext is MIT licensed. Parts of its geometry behavior are adapted from
MIT-licensed Morphicons, and its font reader is derived from the MIT-licensed
`icon_font_generator`; exact revisions and notices are in
`THIRD_PARTY_NOTICES.md`.

This is an independent project. It is not affiliated with or endorsed by the
Flutter project or the Morphicons project.
