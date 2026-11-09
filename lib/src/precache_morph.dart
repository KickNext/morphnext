import 'package:flutter/widgets.dart';

import 'cache/morph_cache.dart';
import 'morph_repository.dart';
import 'widgets/morph_icon_frame.dart';

/// Prepares a bundled-font icon pair in the widgets' existing bounded cache.
///
/// Call from an event handler or [State.didChangeDependencies]. The asset
/// bundle, direction and font axes are captured synchronously from [context].
/// Use the same overrides as the widget that will display the transition.
/// Set [bidirectional] to also prepare the reverse transition.
///
/// Completes with an error if the pair cannot be prepared; callers can catch
/// that error while widgets continue to use their native-icon fallback.
/// Equal icons require no preparation. Cached entries can later be evicted;
/// this does not reserve memory or guarantee that a future lookup is a hit.
/// Respects [MorphCache] limits and disabling; when disabled, preparation
/// completes but no completed plan is retained.
Future<void> precacheMorph(
  BuildContext context, {
  required IconData from,
  required IconData to,
  bool bidirectional = false,
  TextDirection? textDirection,
  double? fill,
  double? weight,
  double? grade,
  double? opticalSize,
  FontWeight? fontWeight,
}) {
  assert(fill == null || 0 <= fill && fill <= 1);
  assert(weight == null || weight > 0);
  assert(opticalSize == null || opticalSize > 0);
  if (from == to) return Future<void>.value();
  final style = resolveMorphIconStyle(
    context,
    size: null,
    color: null,
    textDirection: textDirection,
    applyTextScaling: false,
    fill: fill,
    weight: weight,
    grade: grade,
    opticalSize: opticalSize,
    shadows: null,
    blendMode: null,
    fontWeight: fontWeight,
  );
  final repository = MorphRepository.forBundle(DefaultAssetBundle.of(context));
  return Future.wait(<Future<Object>>[
    repository.planFor(from, to, style.textDirection, style.fontSelection),
    if (bidirectional)
      repository.planFor(to, from, style.textDirection, style.fontSelection),
  ]).then<void>((_) {});
}
