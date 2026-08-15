# Contributing

Thanks for helping improve morphnext. Keep changes focused, tested, and
compatible with the existing public API unless a wider change has a
demonstrated use case.

## Setup

Use the latest stable Flutter SDK supported by `pubspec.yaml`, then run:

```console
flutter pub get
flutter test
flutter analyze --fatal-infos --fatal-warnings
dart format --output=none --set-exit-if-changed .
```

Changes to the example must also pass:

```console
cd example
flutter test
flutter build web --release
```

## Tests

Add the smallest test that demonstrates a behavior change or regression.
Binary font fixtures and icon artwork must be self-authored or have a license
that permits redistribution with complete attribution.

To regenerate visual baselines:

```console
flutter test --update-goldens test/morphnext_golden_test.dart
```

Inspect changed images before submitting them.

Run the exhaustive renderer audit locally from the example package when font
or outline handling changes. It is intentionally excluded from the default
test suite and CI:

```console
cd example
flutter test tool/renderer_visual_audit_test.dart
```

## Pull requests

Explain the user-visible result, include tests, update documentation when the
contract changes, and keep formatting and analysis clean. By contributing, you
agree that your work is distributed under this repository's MIT license.
