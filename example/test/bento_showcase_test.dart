import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphnext/morphnext.dart';
import 'package:morphnext_example/bento_showcase.dart';
import 'package:reel_text/reel_text.dart';
import 'package:url_launcher/link.dart';

void main() {
  testWidgets('wide bento exposes all interactive scenes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const _TestApp(child: MorphBentoShowcase()));

    for (final key in <String>[
      'bento-volume',
      'bento-sync',
      'bento-weather',
      'bento-travel',
      'bento-hatch',
      'bento-drinks',
      'bento-sports',
      'bento-seasons',
      'bento-reel-loop',
    ]) {
      expect(find.byKey(ValueKey<String>(key)), findsOneWidget);
    }
    expect(
      find.byKey(const ValueKey<String>('bento-layout-wide')),
      findsOneWidget,
    );
    final sports = tester.getRect(
      find.byKey(const ValueKey<String>('bento-sports')),
    );
    final volume = tester.getRect(
      find.byKey(const ValueKey<String>('bento-volume')),
    );
    final weather = tester.getRect(
      find.byKey(const ValueKey<String>('bento-weather')),
    );
    final drinks = tester.getRect(
      find.byKey(const ValueKey<String>('bento-drinks')),
    );
    expect(sports.height, closeTo(weather.height, 0.1));
    expect(sports.width, greaterThan(weather.width));
    expect(volume.width, closeTo(weather.width, 0.1));
    expect(volume.height, lessThan(weather.height));
    expect(weather.height, greaterThan(drinks.height));
    expect(weather.width, closeTo(drinks.width, 0.1));
    expect(find.byKey(const ValueKey<String>('physics-ball')), findsOneWidget);
    for (var i = 0; i < 7; i++) {
      expect(find.byKey(ValueKey<String>('physics-choice-$i')), findsOneWidget);
    }
    final morphs = tester.widgetList<AnimatedMorphIcon>(
      find.byType(AnimatedMorphIcon),
    );
    expect(morphs, isNotEmpty);
    for (final morph in morphs) {
      expect(morph.spring, same(MorphSprings.snappy));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('sync, volume, travel, hatch, and drinks update their targets', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const _TestApp(child: MorphBentoShowcase()));

    AnimatedMorphIcon morphWithLabel(String label) => tester.widget(
      find.byWidgetPredicate(
        (widget) =>
            widget is AnimatedMorphIcon && widget.semanticLabel == label,
      ),
    );

    final syncAction = find.byKey(const ValueKey<String>('sync-action'));
    final syncActionLabelFinder = find.byKey(
      const ValueKey<String>('sync-action-label'),
    );
    String syncActionLabel() =>
        tester.widget<ReelText>(syncActionLabelFinder).controller!.value;
    final syncBefore = morphWithLabel('Cloud sync status').icon;
    expect(syncBefore, Icons.cloud_upload_outlined);
    expect(syncActionLabel(), 'Sync');
    expect(
      find.byKey(const ValueKey<String>('sync-reel-text-arrow')),
      findsOneWidget,
    );
    expect(find.text('by '), findsOneWidget);
    expect(find.text('reel_text'), findsOneWidget);
    final reelTextLink = tester.widget<Link>(
      find.byKey(const ValueKey<String>('sync-reel-text-link')),
    );
    expect(
      reelTextLink.uri,
      Uri.parse('https://kicknext.github.io/reel_text/'),
    );
    expect(reelTextLink.target, LinkTarget.blank);
    await tester.tap(syncAction);
    await tester.pump();
    final syncing = morphWithLabel('Cloud sync status').icon;
    expect(syncing, isNot(syncBefore));
    expect(syncActionLabel(), 'Syncing.');
    await tester.pump(const Duration(milliseconds: 560));
    expect(syncActionLabel(), 'Syncing..');
    await tester.pump(const Duration(milliseconds: 560));
    expect(syncActionLabel(), 'Syncing...');
    await tester.pump(const Duration(milliseconds: 480));
    await tester.pump();
    expect(morphWithLabel('Cloud sync status').icon, isNot(syncing));
    expect(syncActionLabel(), 'Synced');
    await tester.pump(const Duration(milliseconds: 1100));
    expect(syncActionLabel(), 'Reset');
    await tester.tap(syncAction);
    await tester.pump();
    expect(morphWithLabel('Cloud sync status').icon, syncBefore);
    expect(syncActionLabel(), 'Sync');

    final volumeBefore = morphWithLabel('Volume level').icon;
    final volumeSlider = tester.widget<Slider>(
      find.byKey(const ValueKey<String>('volume-slider')),
    );
    volumeSlider.onChanged!(0);
    await tester.pump();
    expect(morphWithLabel('Volume level').icon, isNot(volumeBefore));

    final travelBefore = morphWithLabel('Selected travel mode').icon;
    final routeSlider = tester.widget<Slider>(
      find.byKey(const ValueKey<String>('travel-route-slider')),
    );
    routeSlider.onChanged!(5);
    await tester.pump();
    expect(morphWithLabel('Selected travel mode').icon, isNot(travelBefore));

    final hatchBefore = morphWithLabel('Creature hatch stage').icon;
    final hatchLabel = find.text('Hatch');
    await tester.tap(hatchLabel);
    await tester.pump();
    expect(morphWithLabel('Creature hatch stage').icon, isNot(hatchBefore));

    final drinkBefore = morphWithLabel('Selected drink').icon;
    await tester.tap(find.byKey(const ValueKey<String>('drink-choice-3')));
    await tester.pump();
    expect(morphWithLabel('Selected drink').icon, isNot(drinkBefore));
  });

  testWidgets('ball physics and the reel loop produce new icon targets', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const _TestApp(child: MorphBentoShowcase()));

    AnimatedMorphIcon morphWithLabel(String label) => tester.widget(
      find.byWidgetPredicate(
        (widget) =>
            widget is AnimatedMorphIcon && widget.semanticLabel == label,
      ),
    );

    final ballBefore = morphWithLabel('Selected sport').icon;
    final sports = tester.getRect(
      find.byKey(const ValueKey<String>('bento-sports')),
    );
    final firstBall = find.byKey(const ValueKey<String>('physics-ball'));
    final floor = tester.getCenter(firstBall).dy;
    await tester.tap(find.byKey(const ValueKey<String>('physics-drop')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 280));
    final apex = tester.getCenter(firstBall).dy;
    expect(floor - apex, greaterThan(sports.height * 0.45));

    await tester.tap(find.byKey(const ValueKey<String>('physics-drop')));
    await tester.pump(const Duration(milliseconds: 16));
    final afterAirTap = tester.getCenter(firstBall).dy;
    expect(floor - afterAirTap, greaterThan(sports.height * 0.4));

    await tester.tap(find.byKey(const ValueKey<String>('physics-choice-2')));
    await tester.pump();
    expect(morphWithLabel('Selected sport').icon, isNot(ballBefore));

    final loopBefore = morphWithLabel('Synchronized reel icon').icon;
    final loopWordFinder = find.byKey(const ValueKey<String>('reel-loop-word'));
    String loopWord() =>
        tester.widget<ReelText>(loopWordFinder).controller!.value;
    expect(loopWord(), 'reel');
    final loopLink = tester.widget<Link>(
      find.byKey(const ValueKey<String>('reel-loop-link')),
    );
    expect(loopLink.uri, Uri.parse('https://kicknext.github.io/reel_text/'));
    expect(loopLink.target, LinkTarget.blank);
    expect(
      find.byKey(const ValueKey<String>('reel-loop-card-link')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('reel-loop-link-arrow')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 1900));
    await tester.pump();
    expect(morphWithLabel('Synchronized reel icon').icon, isNot(loopBefore));
    expect(loopWord(), 'text');
    await tester.pump(const Duration(milliseconds: 1900));
    await tester.pump();
    expect(loopWord(), 'reel');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact bento collapses into one overflow-free column', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 3400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const _TestApp(child: MorphBentoShowcase()));

    expect(
      find.byKey(const ValueKey<String>('bento-layout-compact')),
      findsOneWidget,
    );
    final volume = tester.getRect(
      find.byKey(const ValueKey<String>('bento-volume')),
    );
    final sync = tester.getRect(
      find.byKey(const ValueKey<String>('bento-sync')),
    );
    final reelLoop = tester.getRect(
      find.byKey(const ValueKey<String>('bento-reel-loop')),
    );
    final sports = tester.getRect(
      find.byKey(const ValueKey<String>('bento-sports')),
    );
    final weatherIcon = tester.getRect(
      find.byWidgetPredicate(
        (widget) =>
            widget is AnimatedMorphIcon &&
            widget.semanticLabel == 'Selected city weather',
      ),
    );
    final weatherPicker = tester.getRect(
      find.byKey(const ValueKey<String>('weather-picker')),
    );
    final travelIcon = tester.getRect(
      find.byWidgetPredicate(
        (widget) =>
            widget is AnimatedMorphIcon &&
            widget.semanticLabel == 'Selected travel mode',
      ),
    );
    final routeSlider = tester.getRect(
      find.byKey(const ValueKey<String>('travel-route-slider')),
    );
    expect(volume.center.dx, closeTo(sync.center.dx, 0.1));
    expect(sports.top, lessThan(sync.top));
    expect(sync.top, greaterThan(sports.bottom));
    expect(volume.top, greaterThan(sync.top));
    expect(
      find.byKey(const ValueKey<String>('weather-layout-mobile')),
      findsOneWidget,
    );
    expect(weatherIcon.bottom, lessThan(weatherPicker.top));
    expect(
      find.byKey(const ValueKey<String>('travel-layout-mobile')),
      findsOneWidget,
    );
    expect(travelIcon.bottom, lessThan(routeSlider.top));
    expect(reelLoop.bottom, lessThanOrEqualTo(3400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('medium bento uses balanced two-column rows', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const _TestApp(child: MorphBentoShowcase()));

    expect(
      find.byKey(const ValueKey<String>('bento-layout-medium')),
      findsOneWidget,
    );
    final weather = tester.getRect(
      find.byKey(const ValueKey<String>('bento-weather')),
    );
    final sync = tester.getRect(
      find.byKey(const ValueKey<String>('bento-sync')),
    );
    final travel = tester.getRect(
      find.byKey(const ValueKey<String>('bento-travel')),
    );
    final hatch = tester.getRect(
      find.byKey(const ValueKey<String>('bento-hatch')),
    );

    expect(weather.width, closeTo(sync.width, 0.1));
    expect(weather.top, closeTo(sync.top, 0.1));
    expect(travel.width, closeTo(hatch.width, 0.1));
    expect(travel.top, greaterThan(weather.bottom));
    expect(
      find.byKey(const ValueKey<String>('weather-layout-mobile')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

final class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(width: 1120, child: child),
      ),
    ),
  );
}
