import 'package:flutter/material.dart';
import 'package:morphnext/morphnext.dart';

void main() => runApp(const MorphnextExample());

class MorphnextExample extends StatefulWidget {
  const MorphnextExample({super.key});

  @override
  State<MorphnextExample> createState() => _MorphnextExampleState();
}

class _MorphnextExampleState extends State<MorphnextExample> {
  var _menuOpen = false;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: IconButton(
          tooltip: _menuOpen ? 'Close menu' : 'Open menu',
          onPressed: () => setState(() => _menuOpen = !_menuOpen),
          icon: AnimatedMorphIcon(
            icon: _menuOpen ? Icons.close : Icons.menu,
            size: 48,
            semanticLabel: _menuOpen ? 'Close menu' : 'Open menu',
          ),
        ),
      ),
    ),
  );
}
