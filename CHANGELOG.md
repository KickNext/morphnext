# Changelog

## Unreleased

- Fix morphs blowing up when a spring carries progress below 0, as
  `AnimatedMorphIcon` and `MorphOutlinePlan.interpolate` allow down to -0.25.
  A contour that shrinks to a point scaled by its tiny end scale raised to a
  negative power, about 16 times its size at -0.2, so letter morphs with
  different contour counts grew up to 22 times larger than either end. Past
  either end a contour's scale now continues in a straight line wherever it
  would grow, and between the ends nothing changes.

## 0.7.1

- `MorphOutline.placed` and `MorphOutline.combine` keep the points each glyph
  was sampled at, so placing a glyph no longer changes how it morphs. They
  used to sample the outline again from contours that sampling had already
  turned around, which started some of them at another corner, most often in
  CFF fonts. They no longer sample twice, either.
- Add `MorphFont.axes`, the tags of a variable font's design axes.

## 0.7.0

- Add `precacheMorph`, including optional reverse-pair preparation using the
  widgets' existing bounded caches.
- Add `onFallback` and `MorphFallbackDetails` to both widgets for per-request
  diagnostics in debug and release, with stale-request and disposal guards.
- Add an experimental glyph outline API, so packages can morph more than
  icons without importing `lib/src`. `MorphFont` reads glyphs from TrueType or
  CFF font bytes in ems about their pen position and baseline.
  `MorphOutline.placed` and `MorphOutline.combine` lay glyphs out as one
  outline, and `MorphOutlinePlan` morphs one outline into another. Thanks to
  [Drei Guintu](https://github.com/alguintu) for the first version.
- Prepare morphs faster: precompute contour metrics and pair costs during
  assignment, and skip assignment work when each role has exactly one contour.
- Add geometry microbenchmarks and a standalone example performance harness.

## 0.6.1

- Update the web showcase to Lucide 3.1.17.
- Generate its searchable icon catalog in CI and deployment workflows for
  reliable icon package updates.
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
