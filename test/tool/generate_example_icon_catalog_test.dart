import 'package:flutter_test/flutter_test.dart';

import '../../tool/generate_example_icon_catalog.dart';

void main() {
  test(
    'parses literal icons, preserves RTL, and skips aliases and duplicates',
    () {
      const source = '''
static const IconData legacy_add = IconData(
  0xe001,
  fontFamily: 'MaterialIcons',
);
static const IconData add = IconData(0xe001, fontFamily: 'MaterialIcons');
static const IconData add_legacy_duplicate =
    IconData(0xe001, fontFamily: 'MaterialIcons');
static const IconData arrow_back = IconData(
  0xe002,
  fontFamily: 'MaterialIcons',
  matchTextDirection: true,
);
static const IconData home = IconData(0xe003, fontFamily: 'MaterialIcons');
static const IconData house = IconData(0xe003, fontFamily: 'MaterialIcons');
static const IconData old_add = add;
''';

      expect(
        parseIconSource(source, GeneratedIconFamily.material),
        const <GeneratedIcon>[
          (
            name: 'add',
            codePoint: 0xe001,
            matchTextDirection: false,
            family: GeneratedIconFamily.material,
            fontFamily: 'MaterialIcons',
            fontPackage: null,
          ),
          (
            name: 'arrow_back',
            codePoint: 0xe002,
            matchTextDirection: true,
            family: GeneratedIconFamily.material,
            fontFamily: 'MaterialIcons',
            fontPackage: null,
          ),
          (
            name: 'house',
            codePoint: 0xe003,
            matchTextDirection: false,
            family: GeneratedIconFamily.material,
            fontFamily: 'MaterialIcons',
            fontPackage: null,
          ),
        ],
      );
    },
  );

  test('parses wrapped, untyped, decimal, and camel-case declarations', () {
    const source = '''
static const FaIconData solidHouse = FaIconData(
  IconData(
    61461,
    fontFamily: 'FontAwesomeSolid',
    fontPackage: 'font_awesome_flutter',
  ),
);
static const \$1Circle = IconData(
  0xe001,
  fontFamily: 'ExampleIcons',
  fontPackage: 'example_icons',
);
''';

    expect(
      parseIconSource(source, GeneratedIconFamily.material),
      const <GeneratedIcon>[
        (
          name: '1_circle',
          codePoint: 0xe001,
          matchTextDirection: false,
          family: GeneratedIconFamily.material,
          fontFamily: 'ExampleIcons',
          fontPackage: 'example_icons',
        ),
        (
          name: 'solid_house',
          codePoint: 61461,
          matchTextDirection: false,
          family: GeneratedIconFamily.material,
          fontFamily: 'FontAwesomeSolid',
          fontPackage: 'font_awesome_flutter',
        ),
      ],
    );
  });

  test('renders Cupertino font package metadata', () {
    final output = renderIconCatalog(const <GeneratedIcon>[
      (
        name: 'heart',
        codePoint: 0xf442,
        matchTextDirection: false,
        family: GeneratedIconFamily.cupertino,
        fontFamily: 'CupertinoIcons',
        fontPackage: 'cupertino_icons',
      ),
    ]);

    expect(
      output,
      contains(
        "IconCatalogEntry(name: 'heart', "
        'family: IconCatalogFamily.cupertino, '
        "icon: IconData(0xf442, fontFamily: 'CupertinoIcons', "
        "fontPackage: 'cupertino_icons')),",
      ),
    );
    expect(output, contains('// dart format off'));
  });

  test('marks a native-overflow glyph as unsafe for the Hero', () {
    const wide = (
      name: 'wide',
      codePoint: 0xf001,
      matchTextDirection: false,
      family: GeneratedIconFamily.fontAwesome,
      fontFamily: 'FontAwesomeBrands',
      fontPackage: 'font_awesome_flutter',
    );

    final output = renderIconCatalog(
      const <GeneratedIcon>[wide],
      heroUnsafeIcons: const <GeneratedIcon>{wide},
    );

    expect(output, contains('heroSafe: false'));
  });

  test('renders the font metadata declared by a wrapped icon', () {
    const source = '''
static const FaIconData house = FaIconData(
  IconData(
    0xf015,
    fontFamily: 'FontAwesomeSolid',
    fontPackage: 'font_awesome_flutter',
  ),
);
''';

    final output = renderIconCatalog(
      parseIconSource(source, GeneratedIconFamily.material),
    );

    expect(
      output,
      contains(
        "fontFamily: 'FontAwesomeSolid', "
        "fontPackage: 'font_awesome_flutter')),",
      ),
    );
  });

  test('derives Font Awesome font metadata from its constructors', () {
    const source = '''
static const IconData house = IconDataSolid(0xf015);
static const IconData addressBook = IconDataRegular(0xf2b9);
static const IconData github = IconDataBrands(0xf09b);
''';

    expect(
      parseIconSource(source, GeneratedIconFamily.material),
      const <GeneratedIcon>[
        (
          name: 'address_book',
          codePoint: 0xf2b9,
          matchTextDirection: false,
          family: GeneratedIconFamily.material,
          fontFamily: 'FontAwesomeRegular',
          fontPackage: 'font_awesome_flutter',
        ),
        (
          name: 'github',
          codePoint: 0xf09b,
          matchTextDirection: false,
          family: GeneratedIconFamily.material,
          fontFamily: 'FontAwesomeBrands',
          fontPackage: 'font_awesome_flutter',
        ),
        (
          name: 'house',
          codePoint: 0xf015,
          matchTextDirection: false,
          family: GeneratedIconFamily.material,
          fontFamily: 'FontAwesomeSolid',
          fontPackage: 'font_awesome_flutter',
        ),
      ],
    );
  });

  test('resolves package roots from the example package config', () {
    final roots = parsePackageRoots(
      '''
{
  "configVersion": 2,
  "packages": [
    {"name": "icons", "rootUri": "../icons", "packageUri": "lib/"}
  ]
}
''',
      configUri: Uri.parse(
        'file:///repo/example/.dart_tool/package_config.json',
      ),
    );

    expect(roots['icons'], Uri.parse('file:///repo/example/icons/'));
  });

  test('drops package glyphs that cannot form native endpoints', () {
    const supported = (
      name: 'home',
      codePoint: 0xeb2c,
      matchTextDirection: false,
      family: GeneratedIconFamily.tabler,
      fontFamily: 'tabler-icons',
      fontPackage: 'flutter_tabler_icons',
    );
    const variationSelector = (
      name: 'microphone_filled',
      codePoint: 0xfe0f,
      matchTextDirection: false,
      family: GeneratedIconFamily.tabler,
      fontFamily: 'tabler-icons',
      fontPackage: 'flutter_tabler_icons',
    );
    const specialCharacter = (
      name: 'number_43_small',
      codePoint: 0xfff7,
      matchTextDirection: false,
      family: GeneratedIconFamily.tabler,
      fontFamily: 'tabler-icons',
      fontPackage: 'flutter_tabler_icons',
    );
    const combiningHebrewMark = (
      name: 'quotes',
      codePoint: 0xfb1e,
      matchTextDirection: false,
      family: GeneratedIconFamily.tabler,
      fontFamily: 'tabler-icons',
      fontPackage: 'flutter_tabler_icons',
    );
    const combiningHalfMark = (
      name: 'layout_cards_filled',
      codePoint: 0xfe20,
      matchTextDirection: false,
      family: GeneratedIconFamily.tabler,
      fontFamily: 'tabler-icons',
      fontPackage: 'flutter_tabler_icons',
    );
    const zeroWidthNoBreakSpace = (
      name: 'align_right_2',
      codePoint: 0xfeff,
      matchTextDirection: false,
      family: GeneratedIconFamily.tabler,
      fontFamily: 'tabler-icons',
      fontPackage: 'flutter_tabler_icons',
    );

    expect(
      filterKnownUnsupportedIcons(const [
        variationSelector,
        specialCharacter,
        combiningHebrewMark,
        combiningHalfMark,
        zeroWidthNoBreakSpace,
        supported,
      ]),
      const [supported],
    );
  });

  test('rejects a truncated SDK catalog', () {
    expect(
      () => validateIconCatalog(
        const <GeneratedIconFamily, List<GeneratedIcon>>{},
      ),
      throwsStateError,
    );
  });
}
