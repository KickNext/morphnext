import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:morphnext/morphnext.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'studio.dart';

const double _kShellMaxWidth = 1280;
const String _kThemePreferenceKey = 'morphnext_example_brightness';
const String _kPackagePubspecAsset = 'packages/morphnext/pubspec.yaml';

class ThemePreferenceStore {
  const ThemePreferenceStore();

  Future<Brightness?> loadBrightness() async {
    final value = await SharedPreferencesAsync().getString(
      _kThemePreferenceKey,
    );
    return switch (value) {
      'light' => Brightness.light,
      'dark' => Brightness.dark,
      _ => null,
    };
  }

  Future<void> saveBrightness(Brightness brightness) async {
    await SharedPreferencesAsync().setString(
      _kThemePreferenceKey,
      brightness.name,
    );
  }
}

Future<Brightness?> loadSavedBrightness(ThemePreferenceStore store) async {
  try {
    return await store.loadBrightness();
  } on Object catch (error) {
    debugPrint('Could not load saved theme: $error');
    return null;
  }
}

class MorphnextTopBar extends StatefulWidget {
  const MorphnextTopBar({
    super.key,
    required this.page,
    required this.onPageChanged,
    required this.loadLiveMetadata,
    required this.brightness,
    required this.onBrightnessChanged,
  });

  final int page;
  final ValueChanged<int> onPageChanged;
  final bool loadLiveMetadata;
  final Brightness brightness;
  final ValueChanged<Brightness> onBrightnessChanged;

  @override
  State<MorphnextTopBar> createState() => _MorphnextTopBarState();
}

class _MorphnextTopBarState extends State<MorphnextTopBar> {
  late Future<_PackageStats> _stats;
  Timer? _statsRefreshTimer;
  Timer? _brandMorphTimer;
  IconData _brandIcon = Icons.play_arrow_rounded;

  static const _pageNames = ['RANDOM', 'PLAYGROUND'];
  static const _statsRefreshInterval = Duration(seconds: 125);
  static final _pubDevUri = Uri.parse('https://pub.dev/packages/morphnext');
  static final _githubUri = Uri.parse('https://github.com/KickNext/morphnext');
  static final _pubDevScoreUri = Uri.parse(
    'https://pub.dev/api/packages/morphnext/score',
  );
  static final _githubApiUri = Uri.parse(
    'https://api.github.com/repos/KickNext/morphnext',
  );

  @override
  void initState() {
    super.initState();
    _configureStatsLoader();
    _brandMorphTimer = Timer.periodic(const Duration(milliseconds: 2800), (_) {
      if (!mounted) return;
      setState(() {
        _brandIcon = _brandIcon == Icons.play_arrow_rounded
            ? Icons.pause_rounded
            : Icons.play_arrow_rounded;
      });
    });
  }

  @override
  void didUpdateWidget(covariant MorphnextTopBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loadLiveMetadata != widget.loadLiveMetadata) {
      _configureStatsLoader();
    }
  }

  @override
  void dispose() {
    _statsRefreshTimer?.cancel();
    _brandMorphTimer?.cancel();
    super.dispose();
  }

  void _configureStatsLoader() {
    _statsRefreshTimer?.cancel();
    if (!widget.loadLiveMetadata) {
      _stats = Future.value(const _PackageStats(githubStars: 0, pubLikes: 0));
      return;
    }

    _stats = _loadPackageStats();
    _statsRefreshTimer = Timer.periodic(
      _statsRefreshInterval,
      (_) => _refreshStats(),
    );
  }

  void _refreshStats() {
    if (!mounted || !widget.loadLiveMetadata) return;
    setState(() {
      _stats = _loadPackageStats();
    });
  }

  static Future<_PackageStats> _loadPackageStats() async {
    final values = await Future.wait([
      _loadGithubStars(),
      _loadPubLikes(),
    ]).timeout(const Duration(seconds: 6));
    return _PackageStats(githubStars: values[0], pubLikes: values[1]);
  }

  static Future<int?> _loadGithubStars() async {
    try {
      final response = await http.get(
        _githubApiUri,
        headers: const {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'morphnext_example',
        },
      );
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, Object?>;
      return json['stargazers_count'] as int?;
    } on Object {
      return null;
    }
  }

  static Future<int?> _loadPubLikes() async {
    try {
      final response = await http.get(_pubDevScoreUri);
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, Object?>;
      return json['likeCount'] as int?;
    } on Object {
      return null;
    }
  }

  static Future<void> _open(Uri uri) async {
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!launched) debugPrint('Could not launch $uri');
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        final narrow = constraints.maxWidth < 520;
        final brand = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              key: const ValueKey('app_bar_logo'),
              dimension: compact ? 26 : 30,
              child: AnimatedMorphIcon(
                icon: _brandIcon,
                size: compact ? 22 : 25,
                color: Studio.primary,
                applyTextScaling: false,
                semanticLabel: 'morphnext logo',
              ),
            ),
            if (!narrow) ...[
              SizedBox(width: compact ? 7 : 9),
              // The film's lockup wordmark: Instrument Sans w800, lowercase,
              // tracking pulled in — not the mono voice of the labels.
              Text(
                'morphnext',
                key: const ValueKey('app_bar_title'),
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: Studio.display(
                  size: compact ? 17 : 19,
                  color: Studio.text,
                  weight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ],
          ],
        );
        final tabs = _PageTabs(
          pageNames: _pageNames,
          selected: widget.page,
          onPageChanged: widget.onPageChanged,
          compact: compact,
        );
        final links = FutureBuilder<_PackageStats>(
          future: _stats,
          builder: (context, snapshot) {
            final stats = snapshot.data;
            return _MetadataLinks(
              compact: compact,
              githubStars: stats?.githubStars,
              pubLikes: stats?.pubLikes,
              onOpenPubDev: () => _open(_pubDevUri),
              onOpenGitHub: () => _open(_githubUri),
            );
          },
        );
        final toggle = _ThemeToggleButton(
          brightness: widget.brightness,
          onChanged: widget.onBrightnessChanged,
          compact: compact,
        );
        final actions = Row(
          key: const ValueKey('app_bar_actions'),
          mainAxisSize: MainAxisSize.min,
          children: [
            toggle,
            SizedBox(width: compact ? 6 : 8),
            links,
          ],
        );

        return ColoredBox(
          color: Studio.background,
          child: Center(
            child: ConstrainedBox(
              key: const ValueKey('shell_top_bar_frame'),
              constraints: const BoxConstraints(maxWidth: _kShellMaxWidth),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 14 : 20,
                  vertical: compact ? 10 : 14,
                ),
                child: compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: brand,
                                ),
                              ),
                              const SizedBox(width: 12),
                              actions,
                            ],
                          ),
                          const SizedBox(height: 10),
                          tabs,
                        ],
                      )
                    : SizedBox(
                        height: 48,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: brand,
                            ),
                            Center(child: tabs),
                            Align(
                              alignment: Alignment.centerRight,
                              child: actions,
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ThemeToggleButton extends StatelessWidget {
  const _ThemeToggleButton({
    required this.brightness,
    required this.onChanged,
    required this.compact,
  });

  final Brightness brightness;
  final ValueChanged<Brightness> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isLight = brightness == Brightness.light;
    final label = isLight ? 'Switch to dark theme' : 'Switch to light theme';
    void toggle() => onChanged(isLight ? Brightness.dark : Brightness.light);

    return Semantics(
      button: true,
      label: label,
      onTap: toggle,
      child: SizedBox.square(
        dimension: 48,
        child: ExcludeSemantics(
          child: Center(
            child: Tooltip(
              message: label,
              child: Material(
                color: Studio.inset,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  key: const ValueKey('theme_toggle_button'),
                  onTap: toggle,
                  borderRadius: BorderRadius.circular(999),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: compact ? 36 : 38,
                    width: compact ? 38 : 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Studio.border),
                    ),
                    child: AnimatedMorphIcon(
                      icon: isLight
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      size: compact ? 16 : 17,
                      color: Studio.text,
                      applyTextScaling: false,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PackageStats {
  const _PackageStats({required this.githubStars, required this.pubLikes});

  final int? githubStars;
  final int? pubLikes;
}

class _PageTabs extends StatelessWidget {
  const _PageTabs({
    required this.pageNames,
    required this.selected,
    required this.onPageChanged,
    required this.compact,
  });

  final List<String> pageNames;
  final int selected;
  final ValueChanged<int> onPageChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.noScaling),
      child: Builder(
        builder: (context) {
          final visualTabs = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < pageNames.length; i++)
                _PageTabVisual(
                  label: pageNames[i],
                  selected: i == selected,
                  compact: compact,
                ),
            ],
          );
          final hitTargets = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < pageNames.length; i++)
                _PageTabHitTarget(
                  key: ValueKey('page_tab_${pageNames[i].toLowerCase()}'),
                  label: pageNames[i],
                  selected: i == selected,
                  compact: compact,
                  onTap: () => onPageChanged(i),
                ),
            ],
          );

          return SizedBox(
            key: const ValueKey('page_tabs_frame'),
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ExcludeSemantics(
                  child: Center(
                    child: DecoratedBox(
                      key: const ValueKey('page_tabs_rail'),
                      decoration: BoxDecoration(
                        color: Studio.inset.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Studio.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: visualTabs,
                      ),
                    ),
                  ),
                ),
                Center(child: hitTargets),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PageTabVisual extends StatelessWidget {
  const _PageTabVisual({
    required this.label,
    required this.selected,
    required this.compact,
  });

  final String label;
  final bool selected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? Studio.primary : Studio.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected ? Studio.primary : Studio.transparent,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 16,
          vertical: 9,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.fade,
          softWrap: false,
          style: Studio.mono(
            size: 10.5,
            color: selected ? Studio.onAccent(Studio.primary) : Studio.text,
            weight: FontWeight.w800,
            letterSpacing: 0.7,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _PageTabHitTarget extends StatelessWidget {
  const _PageTabHitTarget({
    super.key,
    required this.label,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      child: SizedBox(
        height: 48,
        child: ExcludeSemantics(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Center(
              child: Opacity(
                opacity: 0,
                child: _PageTabVisual(
                  label: label,
                  selected: selected,
                  compact: compact,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetadataLinks extends StatelessWidget {
  const _MetadataLinks({
    required this.compact,
    required this.githubStars,
    required this.pubLikes,
    required this.onOpenPubDev,
    required this.onOpenGitHub,
  });

  final bool compact;
  final int? githubStars;
  final int? pubLikes;
  final VoidCallback onOpenPubDev;
  final VoidCallback onOpenGitHub;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('app_bar_metadata_links'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _MetricLinkButton(
          buttonKey: const ValueKey('pubdev_link_button'),
          iconKey: const ValueKey('pubdev_svg_icon'),
          metricKey: const ValueKey('pubdev_like_count'),
          tooltip: 'Open pub.dev',
          assetName: 'assets/icons/pubdev.svg',
          value: pubLikes,
          label: 'likes',
          compact: compact,
          colorize: false,
          onPressed: onOpenPubDev,
        ),
        const SizedBox(width: 8),
        _MetricLinkButton(
          buttonKey: const ValueKey('github_link_button'),
          iconKey: const ValueKey('github_svg_icon'),
          metricKey: const ValueKey('github_star_count'),
          tooltip: 'Open GitHub',
          assetName: 'assets/icons/github.svg',
          value: githubStars,
          label: 'stars',
          compact: compact,
          onPressed: onOpenGitHub,
        ),
      ],
    );
  }
}

class _MetricLinkButton extends StatelessWidget {
  const _MetricLinkButton({
    required this.buttonKey,
    required this.iconKey,
    required this.metricKey,
    required this.tooltip,
    required this.assetName,
    required this.onPressed,
    required this.value,
    required this.label,
    required this.compact,
    this.colorize = true,
  });

  final Key buttonKey;
  final Key iconKey;
  final Key metricKey;
  final String tooltip;
  final String assetName;
  final VoidCallback onPressed;
  final int? value;
  final String label;
  final bool compact;
  final bool colorize;

  @override
  Widget build(BuildContext context) {
    final count = _formatCount(value);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: '$tooltip, $count $label',
        onTap: onPressed,
        child: SizedBox(
          height: 48,
          child: ExcludeSemantics(
            child: Center(
              child: Material(
                color: Studio.inset,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  key: buttonKey,
                  onTap: onPressed,
                  borderRadius: BorderRadius.circular(999),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 38,
                    padding: EdgeInsets.only(
                      left: 11,
                      right: compact ? 11 : 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Studio.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset(
                          assetName,
                          key: iconKey,
                          width: 17,
                          height: 17,
                          colorFilter: colorize
                              ? ColorFilter.mode(Studio.text, BlendMode.srcIn)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        AnimatedSwitcher(
                          key: metricKey,
                          duration: const Duration(milliseconds: 260),
                          child: Text(
                            count,
                            key: ValueKey(count),
                            style: Studio.mono(
                              size: 11,
                              color: Studio.text,
                              weight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                        ),
                        if (!compact) ...[
                          const SizedBox(width: 4),
                          Text(
                            label,
                            style: Studio.mono(
                              size: 10,
                              color: Studio.faint,
                              weight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatCount(int? value) {
  if (value == null) return '...';
  if (value < 1000) return '$value';
  if (value < 1000000) {
    final scaled = value / 1000;
    return scaled < 10 ? '${scaled.toStringAsFixed(1)}k' : '${scaled.round()}k';
  }
  final scaled = value / 1000000;
  return scaled < 10 ? '${scaled.toStringAsFixed(1)}m' : '${scaled.round()}m';
}

class MorphnextFooter extends StatefulWidget {
  const MorphnextFooter({super.key});

  @override
  State<MorphnextFooter> createState() => _MorphnextFooterState();
}

class _MorphnextFooterState extends State<MorphnextFooter> {
  late final Future<String> _packageLabel = _loadPackageLabel();
  late final int _year = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;
    final brightness = Theme.of(context).brightness;
    // The film's furniture line — small mono, widely tracked, well under the
    // page's voice ('KickNext · morphnext' in the preview's bottom corner).
    TextStyle footerStyle({Color? color}) => Studio.mono(
      size: 11,
      color: color ?? Studio.faint,
      weight: FontWeight.w600,
      letterSpacing: 1.2,
    );
    final items = <Widget>[
      Text('KickNext', style: footerStyle()),
      const _FooterDivider(),
      FutureBuilder<String>(
        future: _packageLabel,
        builder: (context, snapshot) =>
            Text(snapshot.data ?? 'morphnext', style: footerStyle()),
      ),
      const _FooterDivider(),
      Text('MIT', style: footerStyle(color: Studio.muted)),
      const _FooterDivider(),
      Text('$_year', style: footerStyle(color: Studio.muted)),
    ];

    return DecoratedBox(
      key: const ValueKey('studio_footer'),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Studio.border)),
      ),
      child: KeyedSubtree(
        key: ValueKey<String>('footer-theme-${brightness.name}'),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: compact ? 12 : 14),
          child: Center(
            heightFactor: 1,
            child: compact
                ? Wrap(
                    key: const ValueKey('studio_footer_content'),
                    spacing: 10,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: items,
                  )
                : Row(
                    key: const ValueKey('studio_footer_content'),
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        if (i > 0) const SizedBox(width: 14),
                        items[i],
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _FooterDivider extends StatelessWidget {
  const _FooterDivider();

  @override
  Widget build(BuildContext context) {
    // The interpunct the film's furniture line uses, as type rather than as a
    // drawn dot, so it sits on the same baseline as its neighbours.
    return Text(
      '·',
      style: Studio.mono(
        size: 11,
        color: Studio.faint,
        weight: FontWeight.w600,
        height: 1,
      ),
    );
  }
}

Future<String> _loadPackageLabel() async {
  try {
    final pubspec = await rootBundle.loadString(_kPackagePubspecAsset);
    final version = RegExp(
      r'^version:\s*([^\s]+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec)?.group(1);
    return version == null || version.isEmpty
        ? 'morphnext'
        : 'morphnext v$version';
  } on Object {
    return 'morphnext';
  }
}
