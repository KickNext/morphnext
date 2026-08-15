import 'package:flutter/widgets.dart';

part 'icon_catalog.g.dart';

enum IconCatalogFamily {
  material('Material'),
  cupertino('Cupertino'),
  fontAwesome('Font Awesome'),
  lucide('Lucide'),
  tabler('Tabler'),
  remix('Remix');

  const IconCatalogFamily(this.label);

  final String label;
}

@immutable
final class IconCatalogEntry {
  const IconCatalogEntry({
    required this.name,
    required this.family,
    required this.icon,
    this.heroSafe = true,
  });

  final String name;
  final IconCatalogFamily family;
  final IconData icon;

  /// Whether Flutter's native [Icon] contour stays inside its size square.
  final bool heroSafe;

  String get label =>
      '${name[0].toUpperCase()}${name.substring(1).replaceAll('_', ' ')}';
}

final Map<IconData, IconCatalogEntry> iconCatalogByIcon =
    Map<IconData, IconCatalogEntry>.unmodifiable({
      for (final entry in iconCatalog) entry.icon: entry,
    });

/// Icons whose native Flutter rendering is contained by the Hero size square.
final List<IconCatalogEntry> heroIconCatalog =
    List<IconCatalogEntry>.unmodifiable(<IconCatalogEntry>[
      for (final entry in iconCatalog)
        if (entry.heroSafe) entry,
    ]);

final _querySeparators = RegExp(r'[\s_]+');

List<IconCatalogEntry> searchIconCatalog({
  String query = '',
  IconCatalogFamily? family,
}) {
  final normalized = query.trim().toLowerCase().replaceAll(
    _querySeparators,
    '_',
  );
  final result = <IconCatalogEntry>[
    for (final entry in iconCatalog)
      if ((family == null || entry.family == family) &&
          (normalized.isEmpty || entry.name.contains(normalized)))
        entry,
  ];
  if (normalized.isEmpty) return result;

  int rank(IconCatalogEntry entry) {
    if (entry.name == normalized) return 0;
    if (entry.name.startsWith(normalized)) return 1;
    return 2;
  }

  result.sort((left, right) {
    final byRank = rank(left).compareTo(rank(right));
    return byRank != 0 ? byRank : left.name.compareTo(right.name);
  });
  return result;
}
