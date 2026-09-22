import 'package:flutter/widgets.dart';

import '../font/binary_reader.dart';
import '../morph_fallback_details.dart';

final Set<Object> _reportedMorphFailures = <Object>{};

void reportMorphFailureOnce({
  required IconData from,
  required IconData to,
  required TextDirection direction,
  required Object error,
  StackTrace? stack,
  ValueChanged<MorphFallbackDetails>? onFallback,
}) {
  if (onFallback != null) {
    try {
      onFallback(
        MorphFallbackDetails(
          from: from,
          to: to,
          error: error,
          stackTrace: stack ?? StackTrace.empty,
        ),
      );
    } catch (callbackError, callbackStack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: callbackError,
          stack: callbackStack,
          library: 'morphnext',
          context: ErrorDescription('while calling onFallback'),
        ),
      );
    }
    return;
  }
  assert(() {
    if (error is FontDataException && error.cause == null) return true;

    String? assetKey;
    String? tableTag;
    Object deepest = error;
    Object? cursor = error;
    while (cursor is FontDataException) {
      assetKey ??= cursor.assetKey;
      tableTag ??= cursor.tableTag;
      deepest = cursor;
      cursor = cursor.cause;
    }
    final format = switch (tableTag) {
      'CFF ' => 'cff1',
      'glyf' || 'loca' => 'truetype',
      null => null,
      _ => 'sfnt',
    };
    final key = (
      from,
      to,
      direction,
      from.fontFamily,
      to.fontFamily,
      assetKey,
      error.runtimeType,
      format,
      deepest.toString(),
    );
    if (_reportedMorphFailures.add(key)) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'morphnext',
          context: ErrorDescription('while preparing an IconData morph'),
        ),
      );
    }
    return true;
  }());
}
