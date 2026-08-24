# Changelog

## 0.6.1

- Update the web showcase to Lucide 3.1.17.
- Generate its searchable icon catalog during builds for reliable icon package
  updates.
- Keep the pub.dev package compact by shipping the focused example without the
  full web showcase sources.

## 0.6.0

- Add configurable application-wide morph cache limits, public cache statistics,
  clearing, disabling, and resetting.

## 0.5.0

- Add controlled `MorphIcon` and interruptible `AnimatedMorphIcon` widgets.
- Add `AnimatedMorphIcon.onEnd`, `MorphSprings` presets, and custom Flutter
  `SpringDescription` support.
- Resolve bundled icon fonts automatically from Flutter's font manifest.
- Support TrueType, variable TrueType, and CFF1 icon outlines.
- Follow Flutter `Icon` styling, layout, RTL, semantics, and reduced-motion
  conventions.
- Keep unsupported or unavailable fonts usable through native-icon fallback.
- Bound geometry caches for long-running applications.
- Require Dart 3.9 or newer while retaining Flutter 3.32 as the minimum.
