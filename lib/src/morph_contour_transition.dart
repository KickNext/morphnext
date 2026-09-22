/// How contours without a corresponding endpoint appear or disappear.
///
/// Matching contours retain the usual rotation/scale morph in either mode.
enum MorphContourTransition {
  /// Preserves the original polar interpolation, including rapid shrinkage
  /// when a contour disappears. This is the compatibility default.
  legacy,

  /// Changes unmatched contours' size linearly with morph progress.
  ///
  /// Appearance and disappearance use symmetric interpolation. Progress for
  /// these contours is clamped to 0–1 so spring overshoot cannot bring a
  /// disappeared contour back or reflect a newly appearing contour.
  /// The spring still controls progress over time; this is not a linear timer.
  linear,
}
