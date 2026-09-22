// Run with `dart run tool/benchmark_geometry.dart`.
// This isolates geometry CPU work; it does not measure Flutter frame times.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:morphnext/src/geometry/morph_plan.dart';
import 'package:morphnext/src/geometry/resample.dart';
import 'package:morphnext/src/geometry/shape.dart';

void main() {
  final results = <String, Object>{};
  var checksum = 0.0;
  for (final count in <int>[1, 6, 9]) {
    final source = _shape(count, 0);
    final target = _shape(count, 0.7);
    results['plan_${count}_contours'] = _measure(() {
      final plan = buildMorphPlan(source, target);
      checksum += plan.items.first.theta;
    });
    var plan = buildMorphPlan(source, target);
    var reverse = false;
    results['retarget_${count}_contours'] = _measure(() {
      reverse = !reverse;
      plan = buildMorphPlan(plan.snapshot(0.37), reverse ? source : target);
      checksum += plan.items.first.source[0];
    });
    for (final icons in <int>[1, 20, 100]) {
      final output = plan.allocateOutput();
      results['interpolate_${count}_contours_${icons}_icons'] = _measure(() {
        for (var icon = 0; icon < icons; icon++) {
          plan.interpolate((icon + 1) / (icons + 1), output);
          checksum += output.first[0];
        }
      });
    }
  }
  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert(<String, Object>{
      'runtime': Platform.version,
      'mode': 'Dart VM microbenchmark; not Flutter frame timings',
      'warmup': 20,
      'samples': 100,
      'unit': 'microseconds',
      'results': results,
      'checksum': checksum,
    }),
  );
}

Map<String, double> _measure(void Function() action) {
  for (var i = 0; i < 20; i++) {
    action();
  }
  final times = <double>[];
  final watch = Stopwatch();
  for (var i = 0; i < 100; i++) {
    watch.reset();
    watch.start();
    action();
    watch.stop();
    times.add(watch.elapsedTicks * 1000000 / watch.frequency);
  }
  times.sort();
  return <String, double>{'p50': times[49], 'p95': times[94]};
}

MorphShape _shape(int count, double phase) =>
    sampledShapeFromPointBuffers(<Float64List>[
      for (var contour = 0; contour < count; contour++)
        Float64List.fromList(<double>[
          for (var point = 0; point < 128; point++) ...<double>[
            contour * 0.4 +
                (0.1 + 0.02 * math.sin(point * 0.2 + phase)) *
                    math.cos(point * 2 * math.pi / 128 + phase),
            (0.1 + 0.02 * math.sin(point * 0.2 + phase)) *
                math.sin(point * 2 * math.pi / 128 + phase),
          ],
        ]),
    ], fillRule: MorphFillRule.nonZero);
