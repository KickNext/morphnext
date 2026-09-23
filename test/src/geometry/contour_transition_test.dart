import 'package:flutter_test/flutter_test.dart';
import 'package:morphnext/morphnext.dart';
import 'package:morphnext/src/geometry/morph_plan.dart';

import 'morph_plan_test.dart'
    show diskShapeWithHoles, signedArea, expectPointsClose;

void main() {
  final filled = diskShapeWithHoles(0);
  final outlined = diskShapeWithHoles(1);

  test(
    'linear disappearing hole shrinks gradually and reverses symmetrically',
    () {
      final forward = buildMorphPlan(
        outlined,
        filled,
        contourTransition: MorphContourTransition.linear,
      );
      final reverse = buildMorphPlan(
        filled,
        outlined,
        contourTransition: MorphContourTransition.linear,
      );
      final disappearing = forward.items.indexWhere(
        (item) => item.targetCollapsed,
      );
      final appearing = reverse.items.indexWhere(
        (item) => item.sourceCollapsed,
      );
      final originalArea = signedArea(forward.items[disappearing].source).abs();
      for (final t in [0.0, 0.25, 0.5, 0.75, 1.0]) {
        final points = forward.interpolatedCopy(t)[disappearing];
        expect(
          signedArea(points).abs(),
          closeTo(originalArea * (1 - t) * (1 - t), 1e-9),
        );
        expectPointsClose(points, reverse.interpolatedCopy(1 - t)[appearing]);
      }
    },
  );

  test('linear lifecycle does not reflect or reappear during overshoot', () {
    for (final shapes in [(outlined, filled), (filled, outlined)]) {
      final plan = buildMorphPlan(
        shapes.$1,
        shapes.$2,
        contourTransition: MorphContourTransition.linear,
      );
      final index = plan.items.indexWhere(
        (item) => item.sourceCollapsed || item.targetCollapsed,
      );
      expectPointsClose(
        plan.interpolatedCopy(-0.25)[index],
        plan.items[index].source,
      );
      expectPointsClose(
        plan.interpolatedCopy(1.25)[index],
        plan.items[index].orientedTarget,
      );
    }
  });

  test('default remains legacy and matching contours are unaffected', () {
    final implicit = buildMorphPlan(outlined, filled);
    final legacy = buildMorphPlan(
      outlined,
      filled,
      contourTransition: MorphContourTransition.legacy,
    );
    final linear = buildMorphPlan(
      outlined,
      filled,
      contourTransition: MorphContourTransition.linear,
    );
    for (final t in [-0.25, 0.0, 0.25, 0.5, 0.75, 1.0, 1.25]) {
      expect(implicit.interpolatedCopy(t), legacy.interpolatedCopy(t));
      for (var i = 0; i < legacy.items.length; i++) {
        if (!legacy.items[i].sourceCollapsed &&
            !legacy.items[i].targetCollapsed) {
          expect(linear.interpolatedCopy(t)[i], legacy.interpolatedCopy(t)[i]);
        }
      }
    }
    final index = legacy.items.indexWhere((item) => item.targetCollapsed);
    expect(
      signedArea(legacy.interpolatedCopy(0.25)[index]).abs(),
      lessThan(signedArea(linear.interpolatedCopy(0.25)[index]).abs() / 100),
    );
  });
}
