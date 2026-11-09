# Performance checks

## Geometry CPU benchmark

From the package root:

```console
dart run tool/benchmark_geometry.dart
```

For before/after comparisons prefer an AOT executable, compiled separately at
each revision with the same Dart SDK and benchmark source:

```console
dart compile exe tool/benchmark_geometry.dart -o geometry-benchmark.exe
./geometry-benchmark.exe
```

The JSON output reports p50/p95 in microseconds after 20 warm-up iterations
and 100 samples. It covers one, six (exact assignment), and nine (greedy
assignment) contours, alternating interrupted transitions, and interpolation
for 1/20/100 icons. The interpolation scenarios reuse output buffers.

These are synthetic CPU measurements, not Flutter frame times or font I/O.
They do not establish a device frame budget. Record the SDK, build mode and
machine alongside results; compare several runs on an idle machine. Avoid
hard timing assertions in unit tests. Use the checksum as a quick comparison
signal, not a substitute for geometry and golden tests.

### Local comparison, 2026-09-22

Baseline `361f54d` versus the contour-cost optimization, using the same benchmark
source, Dart 3.13.4 AOT, Windows x64, AMD Ryzen 9 7945HX. Values below are the
median of p50 measurements from three alternating before/after runs, in µs.

| Workload | Before | After |
| --- | ---: | ---: |
| Build, 1 contour | 12.8 | 10.5 |
| Build, 6 contours | 441.6 | 65.1 |
| Build, 9 contours | 214.8 | 101.8 |
| Retarget, 1 contour | 14.4 | 12.4 |
| Retarget, 6 contours | 378.6 | 94.1 |
| Retarget, 9 contours | 264.1 | 147.2 |

Checksums matched across all six runs. These numbers describe this synthetic
workload and machine; they are not an FPS claim or a mobile/web guarantee.

## Flutter preparation and frames

From `example/`:

```console
flutter run --profile -t lib/performance.dart
```

Select 1, 20 or 100 icons, then run cached transitions or rapid interruptions.
Each run measures preparation of `menu ↔ close` with fresh morph caches,
then measures a repeated cached lookup. The standalone harness uses
`MorphCache.clear()` before each run and recreates the icon widgets so previous
animations cannot warm the cache during setup. Platform/OS font-byte caches
may remain warm; this is not a cold disk benchmark.

The next five seconds measure animation frames separately, with either
one-second toggles or 80 ms retargeting. The UI reports preparation time,
frame count, and UI/raster p95 where frame timings are available. This is a
small-icon workload; use the geometry benchmark for multi-contour stress.

Use a physical mobile device in profile mode for frame conclusions. On web,
use Chrome DevTools; the in-app frame sample may be unavailable. Inspect
allocation/heap profiles separately in DevTools, including a stream of unique
pairs and repeated interruptions. The harness does not claim total memory
usage from cache byte budgets.
