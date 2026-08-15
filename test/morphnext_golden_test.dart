import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphnext/morphnext.dart';

import 'support/tolerant_golden_comparator.dart';

void main() {
  late GoldenFileComparator previousComparator;

  setUpAll(() async {
    previousComparator = goldenFileComparator;
    goldenFileComparator = TolerantGoldenComparator(
      Uri.file('test/morphnext_golden_test.dart'),
    );
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  tearDownAll(() => goldenFileComparator = previousComparator);

  testWidgets('material icon morphs remain visually stable', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(720, 480);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    const boundaryKey = ValueKey<String>('material-morphs');
    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ColoredBox(
          color: Color(0xfff3f6fb),
          child: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: _MaterialMorphSheet(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(boundaryKey),
      matchesGoldenFile('goldens/material_morphs.png'),
    );
  });
}

final class _MaterialMorphSheet extends StatelessWidget {
  const _MaterialMorphSheet();

  static const _pairs = <({IconData from, IconData to})>[
    (from: Icons.menu_rounded, to: Icons.close_rounded),
    (from: Icons.favorite_rounded, to: Icons.star_rounded),
    (from: Icons.play_arrow_rounded, to: Icons.pause_rounded),
  ];

  @override
  Widget build(BuildContext context) => Container(
    width: 672,
    height: 432,
    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 28),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: const Color(0xffdce3ed)),
      boxShadow: const <BoxShadow>[
        BoxShadow(
          color: Color(0x140f172a),
          blurRadius: 24,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        for (var index = 0; index < _pairs.length; index++) ...<Widget>[
          _MorphRow(from: _pairs[index].from, to: _pairs[index].to),
          if (index != _pairs.length - 1)
            const Divider(height: 1, color: Color(0xffe8edf4)),
        ],
      ],
    ),
  );
}

final class _MorphRow extends StatelessWidget {
  const _MorphRow({required this.from, required this.to});

  final IconData from;
  final IconData to;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 108,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        _Endpoint(icon: from),
        const _FlowArrow(),
        for (final progress in const <double>[0.25, 0.5, 0.75])
          _MorphStep(from: from, to: to, progress: progress),
        const _FlowArrow(),
        _Endpoint(icon: to),
      ],
    ),
  );
}

final class _Endpoint extends StatelessWidget {
  const _Endpoint({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 76,
    height: 76,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: const Color(0xfff8fafc),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xffd8e0eb)),
    ),
    child: Icon(icon, size: 42, color: const Color(0xff27364a)),
  );
}

final class _MorphStep extends StatelessWidget {
  const _MorphStep({
    required this.from,
    required this.to,
    required this.progress,
  });

  final IconData from;
  final IconData to;
  final double progress;

  @override
  Widget build(BuildContext context) => Container(
    width: 92,
    height: 92,
    padding: const EdgeInsets.fromLTRB(8, 8, 8, 7),
    decoration: BoxDecoration(
      color: const Color(0xffedf4ff),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xffc9dcff)),
    ),
    child: Column(
      children: <Widget>[
        Expanded(
          child: Center(
            child: MorphIcon(
              from: from,
              to: to,
              progress: AlwaysStoppedAnimation<double>(progress),
              size: 48,
              color: const Color(0xff2563eb),
            ),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: progress,
              child: const ColoredBox(
                color: Color(0xff2563eb),
                child: SizedBox(height: 4),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

final class _FlowArrow extends StatelessWidget {
  const _FlowArrow();

  @override
  Widget build(BuildContext context) => const Icon(
    Icons.arrow_forward_rounded,
    size: 22,
    color: Color(0xff9aa8ba),
  );
}
