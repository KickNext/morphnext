import 'dart:collection';

/// A least-recently-used cache bounded by both entry count and retained bytes.
final class SizedLruCache<K extends Object, V extends Object> {
  /// Creates an empty cache with hard entry-count and byte-size limits.
  SizedLruCache({required this.maximumSize, required this.maximumSizeBytes})
    : assert(maximumSize >= 0),
      assert(maximumSizeBytes >= 0);

  /// The maximum number of retained entries.
  final int maximumSize;

  /// The maximum number of retained bytes.
  final int maximumSizeBytes;
  final LinkedHashMap<K, _SizedEntry<V>> _entries =
      LinkedHashMap<K, _SizedEntry<V>>();
  var _currentSizeBytes = 0;

  /// Returns [key] and moves it to the most-recently-used position.
  V? get(K key) {
    final entry = _entries.remove(key);
    if (entry == null) return null;
    _entries[key] = entry;
    return entry.value;
  }

  /// Inserts [value] with an initially unknown byte size.
  void put(K key, V value) {
    _remove(key);
    if (maximumSize == 0 || maximumSizeBytes == 0) return;
    _entries[key] = _SizedEntry<V>(value, 0);
    _trim();
  }

  /// Records [sizeBytes] if [value] is still the value retained for [key].
  bool updateSizeIfSame(K key, V value, int sizeBytes) {
    assert(sizeBytes >= 0);
    final entry = _entries[key];
    if (entry == null || !identical(entry.value, value)) return false;
    _remove(key);
    if (sizeBytes > maximumSizeBytes || maximumSize == 0) return true;
    _entries[key] = _SizedEntry<V>(value, sizeBytes);
    _currentSizeBytes += sizeBytes;
    _trim();
    return true;
  }

  /// Removes [key] only if it still retains the identical [value].
  bool removeIfSame(K key, V value) {
    final entry = _entries[key];
    if (entry == null || !identical(entry.value, value)) return false;
    _remove(key);
    return true;
  }

  void _trim() {
    while (_entries.length > maximumSize ||
        _currentSizeBytes > maximumSizeBytes) {
      _remove(_entries.keys.first);
    }
    assert(_entries.length <= maximumSize);
    assert(_currentSizeBytes >= 0);
    assert(_currentSizeBytes <= maximumSizeBytes);
  }

  void _remove(K key) {
    final removed = _entries.remove(key);
    if (removed == null) return;
    _currentSizeBytes -= removed.sizeBytes;
  }
}

final class _SizedEntry<V extends Object> {
  const _SizedEntry(this.value, this.sizeBytes);

  final V value;
  final int sizeBytes;
}
