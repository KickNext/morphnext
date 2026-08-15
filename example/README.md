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
`/playground`. Its checked-in icon catalog is generated for search and does not
affect applications that depend on `morphnext`.

Run `flutter pub get` in this directory, then refresh the checked-in catalog
from the repository root after upgrading Flutter or an icon dependency:

```console
dart run tool/generate_example_icon_catalog.dart
```
