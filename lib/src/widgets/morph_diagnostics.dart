import 'package:flutter/widgets.dart';

import '../font/binary_reader.dart';

final Set<Object> _reportedMorphFailures = <Object>{};

void reportMorphFailureOnce({
  required IconData from,
  required IconData to,
  required TextDirection direction,
  required Object error,
  StackTrace? stack,
}) {
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
