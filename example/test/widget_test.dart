import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphnext/morphnext.dart';
import 'package:morphnext_example/main.dart';
import 'package:morphnext_example/site_chrome.dart';
import 'package:reel_text/reel_text.dart';

void main() {
  testWidgets('top navigation switches between the two landing pages', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MorphnextExampleApp(loadLiveMetadata: false, useGoogleFonts: false),
    );

    expect(find.byKey(const ValueKey<String>('landing-shell')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('app_bar_title')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('app_bar_logo')), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('page_tab_random')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('page_tab_playground')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('theme_toggle_button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('app_bar_metadata_links')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey<String>('random-page')), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('endless-morph-showcase')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey<String>('playground-page')), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('page_tab_playground')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('playground-page')),
      findsOneWidget,
    );
    expect(find.text('BUILD'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('from-picker')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('random-page')), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('page_tab_random')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('random-page')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('playground-page')), findsNothing);
  });

  testWidgets('top bar toggles the theme across the install block', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MorphnextExampleApp(
        initialBrightnessOverride: Brightness.light,
        loadLiveMetadata: false,
        themePreferenceStore: _TestThemePreferenceStore(),
        useGoogleFonts: false,
      ),
    );

    final shell = find.byKey(const ValueKey<String>('landing-shell'));
    final toggleIcon = find.descendant(
      of: find.byKey(const ValueKey<String>('theme_toggle_button')),
      matching: find.byType(AnimatedMorphIcon),
    );
    final commandField = find.byKey(const ValueKey<String>('install-command'));
    Color commandBackground() =>
        (tester
                    .widget<Container>(
                      find
                          .descendant(
                            of: commandField,
                            matching: find.byType(Container),
                          )
                          .first,
                    )
                    .decoration
                as BoxDecoration)
            .color!;

    final lightScheme = Theme.of(tester.element(shell)).colorScheme;
    expect(Theme.of(tester.element(shell)).brightness, Brightness.light);
    expect(toggleIcon, findsOneWidget);
    expect(
      tester.widget<AnimatedMorphIcon>(toggleIcon).icon,
      Icons.dark_mode_rounded,
    );
    expect(commandBackground(), lightScheme.surfaceContainer);

    await tester.tap(find.byKey(const ValueKey<String>('theme_toggle_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(Theme.of(tester.element(shell)).brightness, Brightness.dark);
    final darkScheme = Theme.of(tester.element(shell)).colorScheme;
    expect(
      tester.widget<AnimatedMorphIcon>(toggleIcon).icon,
      Icons.light_mode_rounded,
    );
    expect(commandBackground(), darkScheme.surfaceContainer);
    expect(commandBackground(), isNot(lightScheme.surfaceContainer));
  });

  testWidgets('random page makes room for the install action below the hero', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? copiedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedText =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await tester.pumpWidget(
      const MorphnextExampleApp(loadLiveMetadata: false, useGoogleFonts: false),
    );

    final pageRect = tester.getRect(
      find.byKey(const ValueKey<String>('random-page')),
    );
    final heroRect = tester.getRect(
      find.byKey(const ValueKey<String>('random-hero-viewport')),
    );
    expect(heroRect.top, closeTo(pageRect.top, 0.1));
    expect(heroRect.height, lessThan(pageRect.height * 0.75));
    expect(
      find.byKey(const ValueKey<String>('morphnext-install-block')),
      findsOneWidget,
    );
    expect(find.text('flutter pub add morphnext'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is AnimatedMorphIcon &&
            widget.semanticLabel == 'Endless random morph preview',
      ),
      findsOneWidget,
    );

    final copyButton = find.byKey(
      const ValueKey<String>('install-copy-button'),
    );
    await tester.tap(copyButton);
    await tester.pump();

    expect(copiedText, 'flutter pub add morphnext');
    expect(
      tester
          .widget<ReelText>(
            find.descendant(of: copyButton, matching: find.byType(ReelText)),
          )
          .controller
          ?.value,
      'Copied',
    );

    await tester.pump(const Duration(milliseconds: 1500));
    expect(
      tester
          .widget<ReelText>(
            find.descendant(of: copyButton, matching: find.byType(ReelText)),
          )
          .controller
          ?.value,
      'Copy',
    );

    for (var i = 0; i < 8; i++) {
      await tester.drag(
        find.byKey(const ValueKey<String>('random-page')),
        const Offset(0, -700),
      );
      await tester.pump();
    }

    expect(
      find.byKey(const ValueKey<String>('morph-bento-section')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey<String>('studio_footer')), findsOneWidget);
    expect(find.text('A TINY UNIVERSE OF STATES.'), findsOneWidget);
  });

  testWidgets('install action stays usable on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MorphnextExampleApp(loadLiveMetadata: false, useGoogleFonts: false),
    );

    final installBlock = find.byKey(
      const ValueKey<String>('morphnext-install-block'),
    );
    await tester.ensureVisible(installBlock);
    await tester.pump();

    expect(installBlock, findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('install-command')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('install-copy-button')),
      findsOneWidget,
    );
    expect(tester.getSize(installBlock).width, lessThanOrEqualTo(358));
    expect(tester.takeException(), isNull);
  });

  testWidgets('constructor searches Cupertino and updates one endpoint', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MorphnextExampleApp(
        initialLocation: '/playground',
        loadLiveMetadata: false,
        useGoogleFonts: false,
      ),
    );

    AnimatedMorphIcon primaryPreview() => tester.widget(
      find.byWidgetPredicate(
        (widget) =>
            widget is AnimatedMorphIcon &&
            widget.semanticLabel == 'Primary morph preview',
      ),
    );

    // The launch button is icon-only, so its wording lives in the tooltip.
    String? launchLabel() => tester
        .widget<Tooltip>(
          find.ancestor(
            of: find.byKey(const ValueKey<String>('implicit-toggle')),
            matching: find.byType(Tooltip),
          ),
        )
        .message;

    final morphStage = find.byKey(
      const ValueKey<String>('primary-morph-stage'),
    );
    final previewFinder = find.byWidgetPredicate(
      (widget) =>
          widget is AnimatedMorphIcon &&
          widget.semanticLabel == 'Primary morph preview',
    );
    expect(
      find.descendant(of: morphStage, matching: find.byType(Text)),
      findsNothing,
    );
    expect(
      find.descendant(of: morphStage, matching: find.byType(DecoratedBox)),
      findsNothing,
    );
    expect(tester.getCenter(previewFinder), tester.getCenter(morphStage));

    final fromPicker = find.byKey(const ValueKey<String>('from-picker'));
    await _reveal(tester, fromPicker);
    await tester.tap(fromPicker);
    await tester.pumpAndSettle();
    expect(find.text('Choose FROM icon'), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('family-cupertino')));
    await tester.enterText(
      find.byKey(const ValueKey<String>('icon-search')),
      'definitely missing glyph',
    );
    await tester.pump();
    expect(find.text('No icons found'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey<String>('icon-search')),
      'heart',
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('icon-result-cupertino-heart')),
    );
    await tester.pumpAndSettle();

    expect(primaryPreview().icon, CupertinoIcons.heart);
    expect(launchLabel(), 'Morph to Close');

    final toPicker = find.byKey(const ValueKey<String>('to-picker'));
    await _reveal(tester, toPicker);
    await tester.tap(toPicker);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('icon-search')),
      'settings',
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('icon-result-material-settings')),
    );
    await tester.pumpAndSettle();

    expect(primaryPreview().icon, CupertinoIcons.heart);
    expect(launchLabel(), 'Morph to Settings');

    await tester.tap(fromPicker);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('family-tabler')));
    await tester.enterText(
      find.byKey(const ValueKey<String>('icon-search')),
      'align box right bottom',
    );
    await tester.pump();
    await tester.tap(
      find.byKey(
        const ValueKey<String>('icon-result-tabler-align_box_right_bottom'),
      ),
    );
    await tester.pumpAndSettle();

    final generatedCode = tester
        .widget<SelectableText>(
          find.byKey(const ValueKey<String>('playground-code')),
        )
        .data!;
    expect(
      generatedCode,
      contains('icon: TablerIcons.align_box_right_bottom,'),
    );
  });

  testWidgets('constructor and Cupertino browser fit a 390-pixel viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MorphnextExampleApp(
        initialLocation: '/playground',
        loadLiveMetadata: false,
        useGoogleFonts: false,
      ),
    );

    expect(tester.takeException(), isNull);
    final fromPicker = find.byKey(const ValueKey<String>('from-picker'));
    expect(MediaQuery.sizeOf(tester.element(fromPicker)).width, 390);
    await tester.ensureVisible(fromPicker);
    await tester.pump();
    await tester.tap(fromPicker);
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(find.byKey(const ValueKey<String>('icon-search')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('family-cupertino')));
    await tester.enterText(
      find.byKey(const ValueKey<String>('icon-search')),
      'heart',
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('icon-result-cupertino-heart')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('playground exposes valid code and copies it', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? copiedText;
    final clipboardWrite = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedText =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
            await clipboardWrite.future;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await tester.pumpWidget(
      const MorphnextExampleApp(
        initialLocation: '/playground',
        loadLiveMetadata: false,
        useGoogleFonts: false,
      ),
    );

    final copyButton = find.byKey(
      const ValueKey<String>('playground-code-copy'),
    );
    await _reveal(tester, copyButton);
    final code = tester
        .widget<SelectableText>(
          find.byKey(const ValueKey<String>('playground-code')),
        )
        .data!;

    expect(code, contains('icon: Icons.menu,'));
    expect(code, isNot(contains('icon: Menu,')));
    await tester.tap(copyButton);
    await tester.pump();

    expect(copiedText, code);
    final animatedCopyIcon = tester.widget<AnimatedMorphIcon>(
      find.byWidgetPredicate(
        (widget) =>
            widget is AnimatedMorphIcon &&
            widget.semanticLabel == 'Code copied',
      ),
    );
    expect(animatedCopyIcon.icon, Icons.check_rounded);
    expect(animatedCopyIcon.spring, MorphSprings.snappy);
    clipboardWrite.complete();
    await tester.pump();
  });

  testWidgets('manual mode exposes exact progress for the selected pair', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MorphnextExampleApp(
        initialLocation: '/playground',
        loadLiveMetadata: false,
        useGoogleFonts: false,
      ),
    );

    final implicit = find.byKey(const ValueKey<String>('implicit-toggle'));
    await _reveal(tester, implicit);
    await tester.tap(implicit);
    await tester.pump();
    final manual = find.text('Manual');
    await _reveal(tester, manual);
    await tester.tap(manual);
    await tester.pump();
    expect(
      tester
          .widget<Slider>(find.byKey(const ValueKey<String>('hero-progress')))
          .value,
      1,
    );
    tester
        .widget<Slider>(find.byKey(const ValueKey<String>('hero-progress')))
        .onChanged!(0.625);
    await tester.pump();

    final preview = tester.widget<MorphIcon>(
      find.byWidgetPredicate(
        (widget) =>
            widget is MorphIcon &&
            widget.semanticLabel == 'Primary morph preview',
      ),
    );
    expect(preview.from, Icons.menu);
    expect(preview.to, Icons.close);
    expect(preview.progress.value, 0.625);
  });
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
}

class _TestThemePreferenceStore extends ThemePreferenceStore {
  const _TestThemePreferenceStore();

  @override
  Future<void> saveBrightness(Brightness brightness) async {}
}
