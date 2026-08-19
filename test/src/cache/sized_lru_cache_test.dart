import 'package:flutter_test/flutter_test.dart';
import 'package:morphnext/src/cache/sized_lru_cache.dart';

void main() {
  test('cache hits refresh least-recently-used order', () {
    final cache = SizedLruCache<int, Object>(
      maximumSize: 2,
      maximumSizeBytes: 8,
    );
    final first = Object();
    final second = Object();
    final third = Object();
    cache
      ..put(1, first)
      ..updateSizeIfSame(1, first, 4)
      ..put(2, second)
      ..updateSizeIfSame(2, second, 4);

    expect(cache.get(1), same(first));
    cache
      ..put(3, third)
      ..updateSizeIfSame(3, third, 4);

    expect(cache.get(2), isNull);
    expect(cache.get(1), same(first));
    expect(cache.get(3), same(third));
  });

  test('an oversized value does not evict resident entries', () {
    final cache = SizedLruCache<int, Object>(
      maximumSize: 3,
      maximumSizeBytes: 8,
    );
    final first = Object();
    final second = Object();
    final oversized = Object();
    cache
      ..put(1, first)
      ..updateSizeIfSame(1, first, 4)
      ..put(2, second)
      ..updateSizeIfSame(2, second, 4)
      ..put(3, oversized)
      ..updateSizeIfSame(3, oversized, 9);

    expect(cache.get(1), same(first));
    expect(cache.get(2), same(second));
    expect(cache.get(3), isNull);
  });

  test('an already-sized oversized value leaves the cache unchanged', () {
    final cache = SizedLruCache<int, Object>(
      maximumSize: 2,
      maximumSizeBytes: 8,
    );
    final resident = Object();
    final oversized = Object();
    cache.putSized(1, resident, 8);

    expect(cache.putSized(2, oversized, 9), isFalse);

    expect(cache.length, 1);
    expect(cache.currentSizeBytes, 8);
    expect(cache.get(1), same(resident));
    expect(cache.get(2), isNull);
  });
}
