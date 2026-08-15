import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphnext/morphnext.dart';

import 'support/test_icons.dart';

void main() {
  testWidgets('public API prepares and paints in a browser', (tester) async {
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: fixtureBundle(),
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: IconTheme(
            data: IconThemeData(size: 24, color: Color(0xff123456)),
            child: Center(
              child: MorphIcon(
                from: testQuadraticIcon,
                to: testCffIcon,
                progress: AlwaysStoppedAnimation<double>(0.5),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MorphIcon), findsOneWidget);
    expect(find.byType(CustomPaint), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
