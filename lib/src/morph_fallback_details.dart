import 'package:flutter/widgets.dart';

/// Why a requested vector transition fell back to ordinary Flutter icons.
@immutable
final class MorphFallbackDetails {
  /// Creates diagnostic information for one failed preparation request.
  const MorphFallbackDetails({
    required this.from,
    required this.to,
    required this.error,
    required this.stackTrace,
  });

  /// Source icon, or the preceding target when a transition was interrupted.
  final IconData from;

  /// Requested target icon.
  final IconData to;

  /// Original font-resolution, decoding or geometry error.
  final Object error;

  /// Stack trace captured when preparation failed.
  final StackTrace stackTrace;
}
