import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphnext_example/icon_catalog.dart';

void main() {
  test('catalog identities are unique and every filter has entries', () {
    final identities = iconCatalog.map(
      (entry) => (
        entry.icon.fontFamily,
        entry.icon.fontPackage,
        entry.icon.codePoint,
        entry.icon.matchTextDirection,
      ),
    );

    for (final family in IconCatalogFamily.values) {
      expect(
        iconCatalog.any((entry) => entry.family == family),
        isTrue,
        reason: '${family.label} filter has no entries',
      );
    }
    expect(identities.toSet(), hasLength(iconCatalog.length));
    expect(iconCatalogByIcon[Icons.menu]?.name, 'menu');
    expect(iconCatalogByIcon[CupertinoIcons.heart]?.name, 'heart');
  });

  test('search composes normalized words and family filtering', () {
    final material = searchIconCatalog(
      query: 'ACCOUNT circle',
      family: IconCatalogFamily.material,
    );
    final cupertino = searchIconCatalog(
      query: 'heart fill',
      family: IconCatalogFamily.cupertino,
    );

    expect(material.map((entry) => entry.name), contains('account_circle'));
    expect(
      material.every((entry) => entry.family == IconCatalogFamily.material),
      isTrue,
    );
    expect(cupertino.map((entry) => entry.name), contains('heart_fill'));
    expect(
      cupertino.every((entry) => entry.family == IconCatalogFamily.cupertino),
      isTrue,
    );
  });

  test('search ranks an exact icon name before containing names', () {
    final settings = searchIconCatalog(
      query: 'settings',
      family: IconCatalogFamily.material,
    );

    expect(settings.first.name, 'settings');
  });

  test('Hero catalog omits only native icons that overflow their size box', () {
    IconCatalogEntry named(String name, IconCatalogFamily family) => iconCatalog
        .singleWhere((entry) => entry.name == name && entry.family == family);

    final safe = named('menu', IconCatalogFamily.material);
    final wide = named('opencart', IconCatalogFamily.fontAwesome);
    final tall = named('frustum_off', IconCatalogFamily.tabler);

    expect(safe.heroSafe, isTrue);
    expect(heroIconCatalog, contains(safe));
    expect(wide.heroSafe, isFalse);
    expect(tall.heroSafe, isFalse);
    expect(heroIconCatalog, isNot(contains(anyOf(wide, tall))));
    expect(heroIconCatalog.every((entry) => entry.heroSafe), isTrue);
  });
}
