import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphnext_example/performance.dart';

void main() {
  testWidgets('idle performance page can be disposed', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MorphPerformancePage()));
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  for (final mode in ['Cached transitions', 'Rapid interruptions']) {
    testWidgets('$mode completes and releases timing callbacks', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: MorphPerformancePage()));
      await tester.tap(find.text(mode));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Preparation, both directions:'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  }
}
