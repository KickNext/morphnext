import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

class TestAssetBundle extends CachingAssetBundle {
  TestAssetBundle(Map<String, Uint8List> assets)
    : _assets = <String, Uint8List>{
        for (final entry in assets.entries)
          entry.key: Uint8List.fromList(entry.value),
      };

  factory TestAssetBundle.fonts({
    required Map<String, List<String>> manifest,
    required Map<String, Uint8List> assets,
  }) {
    final manifestBytes = utf8.encode(
      jsonEncode(<Map<String, Object>>[
        for (final entry in manifest.entries)
          <String, Object>{
            'family': entry.key,
            'fonts': <Map<String, String>>[
              for (final asset in entry.value) <String, String>{'asset': asset},
            ],
          },
      ]),
    );
    return TestAssetBundle(<String, Uint8List>{
      ...assets,
      'FontManifest.json': Uint8List.fromList(manifestBytes),
    });
  }

  final Map<String, Uint8List> _assets;
  final Map<String, int> _loads = <String, int>{};
  final Map<String, int> _failures = <String, int>{};

  int loadCount(String key) => _loads[key] ?? 0;

  void failNext(String key, [int count = 1]) => _failures[key] = count;

  @override
  Future<ByteData> load(String key) async {
    _loads.update(key, (count) => count + 1, ifAbsent: () => 1);
    final failures = _failures[key] ?? 0;
    if (failures > 0) {
      _failures[key] = failures - 1;
      throw StateError('Injected asset failure for $key');
    }
    final bytes = _assets[key];
    if (bytes == null) throw StateError('Missing test asset: $key');
    final copy = Uint8List.fromList(bytes);
    return ByteData.sublistView(copy);
  }
}

final class DelayedTestAssetBundle extends TestAssetBundle {
  DelayedTestAssetBundle(super.assets);

  factory DelayedTestAssetBundle.fonts({
    required Map<String, List<String>> manifest,
    required Map<String, Uint8List> assets,
  }) => DelayedTestAssetBundle(<String, Uint8List>{
    ...assets,
    'FontManifest.json': Uint8List.fromList(
      utf8.encode(
        jsonEncode(<Map<String, Object>>[
          for (final entry in manifest.entries)
            <String, Object>{
              'family': entry.key,
              'fonts': <Map<String, String>>[
                for (final asset in entry.value)
                  <String, String>{'asset': asset},
              ],
            },
        ]),
      ),
    ),
  });

  final Map<String, Completer<void>> _gates = <String, Completer<void>>{};

  void delay(String key) => _gates[key] = Completer<void>();

  void release(String key) => _gates.remove(key)?.complete();

  @override
  Future<ByteData> load(String key) async {
    await _gates[key]?.future;
    return super.load(key);
  }
}
