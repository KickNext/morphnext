import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphnext/morphnext.dart';
import 'package:morphnext_example/endless_morph_showcase.dart';
import 'package:morphnext_example/icon_catalog.dart';

void main() {
  testWidgets('keeps selecting new random targets', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: EndlessMorphShowcase(random: math.Random(7))),
      ),
    );

    AnimatedMorphIcon preview() => tester.widget<AnimatedMorphIcon>(
      find.byWidgetPredicate(
        (widget) =>
            widget is AnimatedMorphIcon &&
            widget.semanticLabel == 'Endless random morph preview',
      ),
    );

    final first = preview();
    expect(first.size, greaterThanOrEqualTo(240));
    expect(first.spring, same(MorphSprings.snappy));
    final firstIcon = first.icon;
    expect(heroIconCatalog.map((entry) => entry.icon), contains(firstIcon));
    expect(find.byType(Text), findsNothing);

    await tester.pump(const Duration(milliseconds: 850));
    final secondIcon = preview().icon;
    expect(secondIcon, isNot(firstIcon));
    expect(heroIconCatalog.map((entry) => entry.icon), contains(secondIcon));

    await tester.pumpAndSettle(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 850));
    expect(preview().icon, isNot(secondIcon));

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('keeps cycling when the theme changes mid-morph', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final brightness = ValueNotifier(Brightness.light);
    addTearDown(brightness.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder<Brightness>(
        valueListenable: brightness,
        builder: (context, value, child) => MaterialApp(
          theme: ThemeData(brightness: value),
          home: Scaffold(body: child),
        ),
        child: EndlessMorphShowcase(random: math.Random(7)),
      ),
    );

    AnimatedMorphIcon preview() => tester.widget<AnimatedMorphIcon>(
      find.byWidgetPredicate(
        (widget) =>
            widget is AnimatedMorphIcon &&
            widget.semanticLabel == 'Endless random morph preview',
      ),
    );

    await tester.pump(const Duration(milliseconds: 850));
    final activeTarget = preview().icon;
    brightness.value = Brightness.dark;
    await tester.pump();
    await tester.pumpAndSettle(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 850));

    expect(preview().icon, isNot(activeTarget));
  });
}
