import 'package:flutter/material.dart';

import 'icon_catalog.dart';
import 'studio.dart';

Future<IconCatalogEntry?> showIconBrowser(
  BuildContext context, {
  required String endpoint,
  required IconData selected,
}) {
  final browser = IconBrowser(endpoint: endpoint, selected: selected);
  if (MediaQuery.sizeOf(context).width < 700) {
    return showModalBottomSheet<IconCatalogEntry>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.92,
        widthFactor: 1,
        child: browser,
      ),
    );
  }
  return showDialog<IconCatalogEntry>(
    context: context,
    builder: (context) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 860,
        height: (MediaQuery.sizeOf(context).height - 48)
            .clamp(320.0, 720.0)
            .toDouble(),
        child: browser,
      ),
    ),
  );
}

class IconBrowser extends StatefulWidget {
  const IconBrowser({
    required this.endpoint,
    required this.selected,
    super.key,
  });

  final String endpoint;
  final IconData selected;

  @override
  State<IconBrowser> createState() => _IconBrowserState();
}

class _IconBrowserState extends State<IconBrowser> {
  final _search = TextEditingController();
  IconCatalogFamily? _family;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = searchIconCatalog(query: _search.text, family: _family);
    final brightness = Theme.of(context).brightness;
    return Padding(
      key: ValueKey<String>('icon-browser-theme-${brightness.name}'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Choose ${widget.endpoint} icon',
                  style: Studio.display(size: 28, weight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Close icon browser',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('icon-search'),
            controller: _search,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Search icons',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _search.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.clear),
                    ),
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: <Widget>[
              _familyChip(label: 'All', value: null),
              for (final family in IconCatalogFamily.values)
                _familyChip(label: family.label, value: family),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${results.length} icons',
            style: Studio.mono(size: 10.5, color: Studio.faint),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: results.isEmpty
                ? const Center(child: Text('No icons found'))
                : GridView.builder(
                    key: const ValueKey<String>('icon-results'),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 148,
                          mainAxisExtent: 132,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemCount: results.length,
                    itemBuilder: (context, index) => _IconTile(
                      entry: results[index],
                      selected: results[index].icon == widget.selected,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _familyChip({
    required String label,
    required IconCatalogFamily? value,
  }) => ChoiceChip(
    key: ValueKey<String>('family-${value?.name ?? 'all'}'),
    label: Text(label),
    selected: _family == value,
    onSelected: (_) => setState(() => _family = value),
  );
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.entry, required this.selected});

  final IconCatalogEntry entry;
  final bool selected;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '${entry.label}, ${entry.family.label}',
    child: Material(
      color: selected
          ? Studio.accentWash(Studio.primary)
          : Studio.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? Studio.accentBorder(Studio.primary) : Studio.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey<String>('icon-result-${entry.family.name}-${entry.name}'),
        onTap: () => Navigator.pop(context, entry),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(entry.icon, size: 36),
              const SizedBox(height: 8),
              Text(
                entry.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              Text(
                entry.family.label,
                style: Studio.mono(size: 9, color: Studio.faint),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
