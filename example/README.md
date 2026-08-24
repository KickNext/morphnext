# morphnext examples

`example.dart` is the compact package example shown on pub.dev:

```console
flutter run -t example.dart
```

`lib/main.dart` is the full marketing showcase built for GitHub Pages. Run it
on any Flutter target with:

```console
flutter run
```

The showcase includes an endless random hero and an interactive constructor at
`/playground`. Its icon catalog is generated locally for search and does not
affect applications that depend on `morphnext`. The generated file is ignored
by Git.

Run `flutter pub get` in both the repository root and this directory, then
generate the catalog from the repository root before analyzing, testing, or
building the showcase:

```console
flutter pub get
flutter pub get --directory example
dart run tool/generate_example_icon_catalog.dart
```
