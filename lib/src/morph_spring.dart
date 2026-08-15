import 'package:flutter/physics.dart';

/// Ready-made spring descriptions for morph transitions.
abstract final class MorphSprings {
  /// A critically damped transition without overshoot.
  static const smooth = SpringDescription(mass: 1, stiffness: 170, damping: 26);

  /// A fast transition with subtle overshoot.
  static const snappy = SpringDescription(mass: 1, stiffness: 420, damping: 30);
}
