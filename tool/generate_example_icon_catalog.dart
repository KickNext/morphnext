import 'dart:convert';
import 'dart:io';

import 'package:morphnext/src/font/open_type_font.dart';

enum GeneratedIconFamily {
  material('MaterialIcons', null),
  cupertino('CupertinoIcons', 'cupertino_icons'),
  fontAwesome('FontAwesomeSolid', 'font_awesome_flutter'),
  lucide('Lucide', 'lucide_icons_flutter'),
  tabler('tabler-icons', 'flutter_tabler_icons'),
  remix('remix', 'remixicon');

  const GeneratedIconFamily(this.defaultFontFamily, this.defaultFontPackage);

  final String defaultFontFamily;
  final String? defaultFontPackage;
}

typedef GeneratedIcon = ({
  String name,
  int codePoint,
  bool matchTextDirection,
  GeneratedIconFamily family,
  String fontFamily,
  String? fontPackage,
});

final _iconDeclaration = RegExp(
  r'static\s+const(?:\s+[A-Za-z][A-Za-z0-9_<>?]*)?\s+'
  r'(\$?[A-Za-z0-9_]+)\s*=\s*(.*?);',
  dotAll: true,
);
final _iconConstructor = RegExp(
  r'\b(IconData|IconDataSolid|IconDataRegular|IconDataBrands)'
  r'\(\s*(0x[0-9a-fA-F]+|[0-9]+)(.*)',
  dotAll: true,
);
final _matchesTextDirection = RegExp(r'matchTextDirection\s*:\s*true');
final _camelBoundary = RegExp(r'([a-z0-9])([A-Z])');
final _literalFontFamily = RegExp(r'''fontFamily\s*:\s*['"]([^'"]+)['"]''');
final _literalFontPackage = RegExp(r'''fontPackage\s*:\s*['"]([^'"]+)['"]''');

List<GeneratedIcon> parseIconSource(String source, GeneratedIconFamily family) {
  final byIdentity = <String, GeneratedIcon>{};
  for (final match in _iconDeclaration.allMatches(source)) {
    final iconData = _iconConstructor.firstMatch(match.group(2)!);
    if (iconData == null) continue;
    final name = _normalizeIconName(match.group(1)!);
    final constructor = iconData.group(1)!;
    final literal = iconData.group(2)!;
    final codePoint = literal.startsWith('0x')
        ? int.parse(literal.substring(2), radix: 16)
        : int.parse(literal);
    final arguments = iconData.group(3)!;
    final matchTextDirection = _matchesTextDirection.hasMatch(arguments);
    final constructorFont = switch (constructor) {
      'IconDataSolid' => ('FontAwesomeSolid', 'font_awesome_flutter'),
      'IconDataRegular' => ('FontAwesomeRegular', 'font_awesome_flutter'),
      'IconDataBrands' => ('FontAwesomeBrands', 'font_awesome_flutter'),
      _ => null,
    };
    final fontFamily =
        _literalFontFamily.firstMatch(arguments)?.group(1) ??
        constructorFont?.$1 ??
        family.defaultFontFamily;
    final fontPackage =
        _literalFontPackage.firstMatch(arguments)?.group(1) ??
        constructorFont?.$2 ??
        family.defaultFontPackage;
    final identity =
        '${family.name}:$fontFamily:$fontPackage:$codePoint:'
        '$matchTextDirection';
    final icon = (
      name: name,
      codePoint: codePoint,
      matchTextDirection: matchTextDirection,
      family: family,
      fontFamily: fontFamily,
      fontPackage: fontPackage,
    );
    final existing = byIdentity[identity];
    if (existing == null || _preferIconName(name, existing.name)) {
      byIdentity[identity] = icon;
    }
  }
  final result = byIdentity.values.toList();
  result.sort((left, right) => left.name.compareTo(right.name));
  return result;
}

List<GeneratedIcon> filterKnownUnsupportedIcons(
  Iterable<GeneratedIcon> icons,
) => <GeneratedIcon>[
  for (final icon in icons)
    if (!_isKnownUnsupportedIcon(icon)) icon,
];

bool _isKnownUnsupportedIcon(GeneratedIcon icon) {
  // flutter_tabler_icons 1.43 assigns some glyphs to Unicode combining marks,
  // variation selectors, and specials. Flutter's text shaper applies those
  // semantics before consulting the icon font, so they cannot be reliable
  // standalone native endpoints.
  return (icon.codePoint >= 0xfe00 && icon.codePoint <= 0xfe0f) ||
      icon.codePoint == 0xfb1e ||
      (icon.codePoint >= 0xfe20 && icon.codePoint <= 0xfe2f) ||
      icon.codePoint == 0xfeff ||
      (icon.codePoint >= 0xfff0 && icon.codePoint <= 0xffff);
}

bool _preferIconName(String candidate, String current) =>
    _aliasPenalty(candidate) <= _aliasPenalty(current);

int _aliasPenalty(String name) {
  final words = name.split('_');
  if (words.contains('legacy') ||
      words.contains('old') ||
      words.contains('deprecated')) {
    return 2;
  }
  if (words.contains('filled')) return 1;
  return 0;
}

String _normalizeIconName(String identifier) => identifier
    .replaceFirst(RegExp(r'^\$'), '')
    .replaceAllMapped(_camelBoundary, (match) => '${match[1]}_${match[2]}')
    .toLowerCase();

String renderIconCatalog(
  Iterable<GeneratedIcon> icons, {
  Set<GeneratedIcon> heroUnsafeIcons = const <GeneratedIcon>{},
}) {
  final output = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND OR COMMIT.')
    ..writeln('// Run: dart run tool/generate_example_icon_catalog.dart')
    ..writeln()
    ..writeln("part of 'icon_catalog.dart';")
    ..writeln()
    ..writeln('// dart format off')
    ..writeln('const iconCatalog = <IconCatalogEntry>[');
  for (final icon in icons) {
    final iconArguments = <String>[
      '0x${icon.codePoint.toRadixString(16)}',
      "fontFamily: '${icon.fontFamily}'",
      if (icon.fontPackage case final fontPackage?)
        "fontPackage: '$fontPackage'",
      if (icon.matchTextDirection) 'matchTextDirection: true',
    ];
    output.writeln(
      "  IconCatalogEntry(name: '${icon.name}', "
      'family: IconCatalogFamily.${icon.family.name}, '
      'icon: IconData(${iconArguments.join(', ')})'
      '${heroUnsafeIcons.contains(icon) ? ', heroSafe: false' : ''}),',
    );
  }
  output
    ..writeln('];')
    ..writeln('// dart format on');
  return output.toString();
}

Set<GeneratedIcon> findHeroUnsafeIcons(
  Iterable<GeneratedIcon> icons,
  Map<(String?, String), OpenTypeFont> fonts,
) => <GeneratedIcon>{
  for (final icon in icons)
    if (!_glyphFitsNativeIconBox(
      icon,
      fonts[(icon.fontPackage, icon.fontFamily)],
    ))
      icon,
};

bool _glyphFitsNativeIconBox(GeneratedIcon icon, OpenTypeFont? font) {
  if (font == null) {
    throw StateError(
      'No font asset configured for ${icon.fontPackage}/${icon.fontFamily}',
    );
  }
  final outline = font.glyphForCodePoint(icon.codePoint);
  final unitsPerEm = outline.metrics.unitsPerEm;
  final leading =
      unitsPerEm - (outline.metrics.ascender - outline.metrics.descender);
  final horizontalOffset = outline.advanceWidth < unitsPerEm
      ? (unitsPerEm - outline.advanceWidth) / 2
      : 0.0;
  const epsilon = 1e-9;
  for (final contour in outline.contours) {
    final points = contour.points;
    for (var index = 0; index < points.length; index += 2) {
      final x = (points[index] + horizontalOffset) / unitsPerEm;
      final y =
          (leading / 2 + outline.metrics.ascender - points[index + 1]) /
          unitsPerEm;
      if (x < -epsilon || x > 1 + epsilon || y < -epsilon || y > 1 + epsilon) {
        return false;
      }
    }
  }
  return true;
}

const _minimumIconCounts = <GeneratedIconFamily, int>{
  GeneratedIconFamily.material: 8000,
  GeneratedIconFamily.cupertino: 1000,
  GeneratedIconFamily.fontAwesome: 1000,
  GeneratedIconFamily.lucide: 1000,
  GeneratedIconFamily.tabler: 3000,
  GeneratedIconFamily.remix: 2000,
};

const _sentinelIconNames = <GeneratedIconFamily, Set<String>>{
  GeneratedIconFamily.material: {'add', 'close', 'menu', 'search'},
  GeneratedIconFamily.cupertino: {'heart', 'house', 'search'},
  GeneratedIconFamily.fontAwesome: {'github', 'house', 'magnifying_glass'},
  GeneratedIconFamily.lucide: {'house', 'search'},
  GeneratedIconFamily.tabler: {'home', 'search'},
  GeneratedIconFamily.remix: {'home_line', 'search_line'},
};

void validateIconCatalog(
  Map<GeneratedIconFamily, List<GeneratedIcon>> catalogByFamily,
) {
  for (final family in GeneratedIconFamily.values) {
    final icons = catalogByFamily[family] ?? const <GeneratedIcon>[];
    final minimum = _minimumIconCounts[family]!;
    if (icons.length < minimum) {
      throw StateError(
        'Suspicious ${family.name} catalog size: '
        '${icons.length}, expected at least $minimum',
      );
    }
    final names = icons.map((icon) => icon.name).toSet();
    final missing = _sentinelIconNames[family]!.difference(names);
    if (missing.isNotEmpty) {
      throw StateError(
        'Required ${family.name} sentinel icons were not parsed: $missing',
      );
    }
  }
}

Map<String, Uri> parsePackageRoots(String source, {required Uri configUri}) {
  final document = jsonDecode(source);
  if (document is! Map<String, Object?>) {
    throw const FormatException('Package config is not a JSON object');
  }
  final packages = document['packages'];
  if (packages is! List<Object?>) {
    throw const FormatException('Package config has no packages list');
  }
  final roots = <String, Uri>{};
  for (final package in packages) {
    if (package is! Map<String, Object?>) continue;
    final name = package['name'];
    final rootUri = package['rootUri'];
    if (name is String && rootUri is String) {
      final resolved = configUri.resolve(rootUri);
      roots[name] = resolved.path.endsWith('/')
          ? resolved
          : resolved.replace(path: '${resolved.path}/');
    }
  }
  return roots;
}

Future<List<GeneratedIcon>> _readPackageIcons({
  required Map<String, Uri> packageRoots,
  required String packageName,
  required String sourcePath,
  required GeneratedIconFamily family,
}) async {
  final packageRoot = packageRoots[packageName];
  if (packageRoot == null) {
    throw StateError(
      'Package $packageName is missing. Run flutter pub get in example/.',
    );
  }
  final sourceFile = File.fromUri(packageRoot.resolve(sourcePath));
  if (!await sourceFile.exists()) {
    throw StateError('Icon source is missing: ${sourceFile.path}');
  }
  return filterKnownUnsupportedIcons(
    parseIconSource(await sourceFile.readAsString(), family),
  );
}

Future<String> findFlutterRoot() async {
  final configured = Platform.environment['FLUTTER_ROOT'];
  if (configured != null && configured.isNotEmpty) return configured;
  final result = await Process.run('flutter', const [
    '--version',
    '--machine',
  ], runInShell: Platform.isWindows);
  if (result.exitCode != 0) {
    throw StateError('flutter --version --machine failed: ${result.stderr}');
  }
  final machine = jsonDecode(result.stdout as String) as Map<String, Object?>;
  final root = machine['flutterRoot'];
  if (root is! String || root.isEmpty) {
    throw const FormatException('Flutter machine output has no flutterRoot');
  }
  return root;
}

Future<Map<(String?, String), OpenTypeFont>> _readIconFonts({
  required Uri flutterSdk,
  required Map<String, Uri> packageRoots,
}) async {
  Uri packageAsset(String package, String path) {
    final root = packageRoots[package];
    if (root == null) {
      throw StateError(
        'Package $package is missing. Run flutter pub get in example/.',
      );
    }
    return root.resolve(path);
  }

  final assets = <(String?, String), Uri>{
    (null, 'MaterialIcons'): flutterSdk.resolve(
      'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ),
    ('cupertino_icons', 'CupertinoIcons'): packageAsset(
      'cupertino_icons',
      'assets/CupertinoIcons.ttf',
    ),
    ('font_awesome_flutter', 'FontAwesomeBrands'): packageAsset(
      'font_awesome_flutter',
      'lib/fonts/Font-Awesome-7-Brands-Regular-400.otf',
    ),
    ('font_awesome_flutter', 'FontAwesomeRegular'): packageAsset(
      'font_awesome_flutter',
      'lib/fonts/Font-Awesome-7-Free-Regular-400.otf',
    ),
    ('font_awesome_flutter', 'FontAwesomeSolid'): packageAsset(
      'font_awesome_flutter',
      'lib/fonts/Font-Awesome-7-Free-Solid-900.otf',
    ),
    ('lucide_icons_flutter', 'Lucide'): packageAsset(
      'lucide_icons_flutter',
      'assets/lucide.ttf',
    ),
    ('flutter_tabler_icons', 'tabler-icons'): packageAsset(
      'flutter_tabler_icons',
      'assets/fonts/tabler-icons.ttf',
    ),
    ('remixicon', 'remix'): packageAsset('remixicon', 'fonts/remix.ttf'),
  };
  final fonts = <(String?, String), OpenTypeFont>{};
  for (final asset in assets.entries) {
    final file = File.fromUri(asset.value);
    if (!await file.exists()) {
      throw StateError('Icon font asset is missing: ${file.path}');
    }
    fonts[asset.key] = OpenTypeFont.parse(await file.readAsBytes());
  }
  return fonts;
}

Future<void> main() async {
  try {
    final repository = File.fromUri(Platform.script).parent.parent;
    final flutterRoot = await findFlutterRoot();
    final sdk = Directory(flutterRoot).uri;
    final materialSource = await File.fromUri(
      sdk.resolve('packages/flutter/lib/src/material/icons.dart'),
    ).readAsString();
    final cupertinoSource = await File.fromUri(
      sdk.resolve('packages/flutter/lib/src/cupertino/icons.dart'),
    ).readAsString();
    final packageConfig = File.fromUri(
      repository.uri.resolve('example/.dart_tool/package_config.json'),
    );
    if (!await packageConfig.exists()) {
      throw StateError(
        'Missing ${packageConfig.path}. Run flutter pub get in example/.',
      );
    }
    final packageRoots = parsePackageRoots(
      await packageConfig.readAsString(),
      configUri: packageConfig.uri,
    );
    final material = parseIconSource(
      materialSource,
      GeneratedIconFamily.material,
    );
    final cupertino = parseIconSource(
      cupertinoSource,
      GeneratedIconFamily.cupertino,
    );
    final fontAwesome = await _readPackageIcons(
      packageRoots: packageRoots,
      packageName: 'font_awesome_flutter',
      sourcePath: 'lib/font_awesome_flutter.dart',
      family: GeneratedIconFamily.fontAwesome,
    );
    final allLucide = await _readPackageIcons(
      packageRoots: packageRoots,
      packageName: 'lucide_icons_flutter',
      sourcePath: 'lib/lucide_icons.dart',
      family: GeneratedIconFamily.lucide,
    );
    final lucide = <GeneratedIcon>[
      for (final icon in allLucide)
        if (icon.fontFamily == GeneratedIconFamily.lucide.defaultFontFamily &&
            !icon.matchTextDirection)
          icon,
    ];
    final tabler = await _readPackageIcons(
      packageRoots: packageRoots,
      packageName: 'flutter_tabler_icons',
      sourcePath: 'lib/flutter_tabler_icons.dart',
      family: GeneratedIconFamily.tabler,
    );
    final remix = await _readPackageIcons(
      packageRoots: packageRoots,
      packageName: 'remixicon',
      sourcePath: 'lib/remixicon.dart',
      family: GeneratedIconFamily.remix,
    );
    final catalogByFamily = <GeneratedIconFamily, List<GeneratedIcon>>{
      GeneratedIconFamily.material: material,
      GeneratedIconFamily.cupertino: cupertino,
      GeneratedIconFamily.fontAwesome: fontAwesome,
      GeneratedIconFamily.lucide: lucide,
      GeneratedIconFamily.tabler: tabler,
      GeneratedIconFamily.remix: remix,
    };
    validateIconCatalog(catalogByFamily);

    final output = File.fromUri(
      repository.uri.resolve('example/lib/icon_catalog.g.dart'),
    );
    final icons = <GeneratedIcon>[
      for (final family in GeneratedIconFamily.values)
        ...catalogByFamily[family]!,
    ];
    final fonts = await _readIconFonts(
      flutterSdk: sdk,
      packageRoots: packageRoots,
    );
    final heroUnsafeIcons = findHeroUnsafeIcons(icons, fonts);
    await output.writeAsString(
      renderIconCatalog(icons, heroUnsafeIcons: heroUnsafeIcons),
    );
    final counts = [
      for (final family in GeneratedIconFamily.values)
        '${family.name}: ${catalogByFamily[family]!.length}',
    ].join(', ');
    stdout.writeln(
      'Generated $counts; excluded ${heroUnsafeIcons.length} native-overflow '
      'glyphs from Hero at ${output.path}',
    );
  } on Object catch (error) {
    stderr.writeln('Icon catalog generation failed: $error');
    exitCode = 1;
  }
}
