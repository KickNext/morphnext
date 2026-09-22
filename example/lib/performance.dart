import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:morphnext/morphnext.dart';

/// Standalone benchmark: flutter run --profile -t lib/performance.dart
void main() => runApp(const MaterialApp(home: MorphPerformancePage()));

/// Measures preparation separately from animated UI/raster frame times.
class MorphPerformancePage extends StatefulWidget {
  const MorphPerformancePage({super.key});

  @override
  State<MorphPerformancePage> createState() => _MorphPerformancePageState();
}

class _MorphPerformancePageState extends State<MorphPerformancePage> {
  late BuildContext _sceneContext;
  int _count = 20;
  int _sampleId = 0;
  bool _running = false;
  IconData _icon = Icons.menu;
  String _result = 'Select a count and run a five-second sample.';
  Timer? _timer;
  bool _recording = false;
  final List<FrameTiming> _frames = [];

  void _record(List<FrameTiming> frames) => _frames.addAll(frames);

  void _stopRecording() {
    if (!_recording) return;
    SchedulerBinding.instance.removeTimingsCallback(_record);
    _recording = false;
  }

  Future<void> _run({required bool interrupt}) async {
    MorphCache.clear();
    setState(() {
      _running = true;
      // Dispose the previous animation before measuring a cold preparation.
      _sampleId++;
      _icon = Icons.menu;
      _result = 'Preparing…';
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    try {
      final watch = Stopwatch()..start();
      await precacheMorph(
        _sceneContext,
        from: Icons.menu,
        to: Icons.close,
        bidirectional: true,
      );
      final cold = watch.elapsedMicroseconds;
      if (!mounted) return;
      watch.reset();
      await precacheMorph(
        _sceneContext,
        from: Icons.menu,
        to: Icons.close,
        bidirectional: true,
      );
      final warm = watch.elapsedMicroseconds;
      watch.stop();
      if (!mounted) return;
      // Do not mix the preparation phase into the frame sample.
      _frames.clear();
      SchedulerBinding.instance.addTimingsCallback(_record);
      _recording = true;
      setState(() {
        _icon = Icons.close;
        _result =
            'Measuring ${interrupt ? 'interruptions' : 'cached transitions'}…';
      });
      _timer = Timer.periodic(Duration(milliseconds: interrupt ? 80 : 1000), (
        _,
      ) {
        if (!mounted) return;
        setState(() => _icon = _icon == Icons.menu ? Icons.close : Icons.menu);
      });
      await Future<void>.delayed(const Duration(seconds: 5));
      if (!mounted) return;
      _timer?.cancel();
      _stopRecording();
      setState(() {
        _result =
            '$_count icons · ${interrupt ? '80 ms retarget' : '1 s toggles'}\n'
            'Preparation, both directions: cold $cold µs / cached $warm µs\n'
            '${_frames.length} frames · UI p95 ${_p95(false)} · raster p95 ${_p95(true)}\n'
            'Profile/release only. Use DevTools for memory and Chrome DevTools on web.';
      });
    } catch (error) {
      if (mounted) setState(() => _result = 'Benchmark failed: $error');
    } finally {
      _timer?.cancel();
      _stopRecording();
      if (mounted) setState(() => _running = false);
    }
  }

  String _p95(bool raster) {
    if (_frames.isEmpty) return 'unavailable';
    final times = [
      for (final frame in _frames)
        (raster ? frame.rasterDuration : frame.buildDuration).inMicroseconds,
    ]..sort();
    return '${(times[(times.length * 0.95).ceil() - 1] / 1000).toStringAsFixed(2)} ms';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopRecording();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Morph performance')),
    body: Builder(
      builder: (context) {
        _sceneContext = context;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<int>(
                segments: [
                  for (final count in [1, 20, 100])
                    ButtonSegment(value: count, label: Text('$count icons')),
                ],
                selected: {_count},
                onSelectionChanged: _running
                    ? null
                    : (value) => setState(() => _count = value.single),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                children: [
                  FilledButton(
                    onPressed: _running ? null : () => _run(interrupt: false),
                    child: const Text('Cached transitions'),
                  ),
                  OutlinedButton(
                    onPressed: _running ? null : () => _run(interrupt: true),
                    child: const Text('Rapid interruptions'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(_result),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < _count; i++)
                        AnimatedMorphIcon(
                          key: ValueKey((_sampleId, i)),
                          icon: _icon,
                          size: 32,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
