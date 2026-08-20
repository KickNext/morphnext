import '../geometry/morph_plan.dart';
import 'sized_lru_cache.dart';

/// Controls the application-wide cache of completed icon morphs.
///
/// The cache is shared by all morphnext widgets in the current Dart isolate.
/// A completed morph is identified by its ordered icon pair, text direction,
/// font parameters, and asset bundle. Morphs built from an interrupted
/// intermediate shape are one-off values and are not retained.
abstract final class MorphCache {
  /// The default maximum number of retained completed morphs.
  static const int defaultMaxMorphs = 128;

  /// The default maximum size of retained morph geometry: 16 MiB.
  static const int defaultMaxBytes = 16 << 20;

  /// The configured maximum number of retained completed morphs.
  ///
  /// This is zero while caching is disabled.
  static int get maxMorphs => MorphCacheStore.instance.maxMorphs;

  /// The configured maximum size of retained morph geometry, in bytes.
  ///
  /// This is zero while caching is disabled.
  static int get maxBytes => MorphCacheStore.instance.maxBytes;

  /// The number of completed morphs currently retained by the cache.
  ///
  /// Morphs that are still being built are not included.
  static int get currentMorphs => MorphCacheStore.instance.currentMorphs;

  /// The size of vector buffers owned by currently retained morphs, in bytes.
  ///
  /// This does not include pending morphs, decoded fonts, sampled source
  /// shapes, Dart object overhead, or memory owned by Flutter.
  static int get currentBytes => MorphCacheStore.instance.currentBytes;

  /// Sets both cache limits and immediately clears all retained morphs.
  ///
  /// A morph is retained only while both limits permit it. A completed morph
  /// larger than [maxBytes] is returned to its caller without being cached and
  /// without evicting existing morphs. Work started before this call may still
  /// finish for its current caller, but its result cannot repopulate the cache.
  ///
  /// Throws an [ArgumentError] when either argument is not positive. Use
  /// [disable] instead of passing zero.
  static void configure({required int maxMorphs, required int maxBytes}) {
    if (maxMorphs <= 0) {
      throw ArgumentError.value(maxMorphs, 'maxMorphs', 'Must be positive');
    }
    if (maxBytes <= 0) {
      throw ArgumentError.value(maxBytes, 'maxBytes', 'Must be positive');
    }
    MorphCacheStore.instance.configure(
      maxMorphs: maxMorphs,
      maxBytes: maxBytes,
    );
  }

  /// Immediately removes all retained morphs without changing the limits.
  ///
  /// Work already in progress may still finish for its current caller, but its
  /// result cannot repopulate the cache.
  static void clear() => MorphCacheStore.instance.clear();

  /// Clears the cache and prevents completed morphs from being retained.
  ///
  /// Morphs are still built and used by current animations. Call [configure]
  /// or [reset] to enable caching again.
  static void disable() => MorphCacheStore.instance.disable();

  /// Restores the default limits and clears all retained morphs.
  static void reset() => MorphCacheStore.instance.configure(
    maxMorphs: defaultMaxMorphs,
    maxBytes: defaultMaxBytes,
  );
}

/// Internal isolate-wide storage shared by repositories for all asset bundles.
final class MorphCacheStore {
  MorphCacheStore._();

  static final MorphCacheStore instance = MorphCacheStore._();

  var _maxMorphs = MorphCache.defaultMaxMorphs;
  var _maxBytes = MorphCache.defaultMaxBytes;
  var _generation = 0;
  var _cache = SizedLruCache<Object, MorphPlan>(
    maximumSize: MorphCache.defaultMaxMorphs,
    maximumSizeBytes: MorphCache.defaultMaxBytes,
  );
  final Map<Object, Future<MorphPlan>> _pending = <Object, Future<MorphPlan>>{};

  int get maxMorphs => _maxMorphs;
  int get maxBytes => _maxBytes;
  int get currentMorphs => _cache.length;
  int get currentBytes => _cache.currentSizeBytes;
  int get generation => _generation;

  Future<MorphPlan> load(
    Object key,
    Future<MorphPlan> Function() create,
    int Function(MorphPlan plan) sizeOf,
  ) {
    final cached = _cache.get(key);
    if (cached != null) return Future<MorphPlan>.value(cached);
    final pending = _pending[key];
    if (pending != null) return pending;

    final requestGeneration = _generation;
    late final Future<MorphPlan> future;
    future = create()
        .then((plan) {
          if (requestGeneration == _generation) {
            _cache.putSized(key, plan, sizeOf(plan));
          }
          return plan;
        })
        .whenComplete(() {
          if (identical(_pending[key], future)) _pending.remove(key);
        });
    _pending[key] = future;
    return future;
  }

  void configure({required int maxMorphs, required int maxBytes}) {
    _maxMorphs = maxMorphs;
    _maxBytes = maxBytes;
    _replaceCache(maxMorphs: maxMorphs, maxBytes: maxBytes);
  }

  void disable() {
    _maxMorphs = 0;
    _maxBytes = 0;
    _replaceCache(maxMorphs: 0, maxBytes: 0);
  }

  void clear() {
    _generation++;
    _cache.clear();
    _pending.clear();
  }

  void _replaceCache({required int maxMorphs, required int maxBytes}) {
    _generation++;
    _cache = SizedLruCache<Object, MorphPlan>(
      maximumSize: maxMorphs,
      maximumSizeBytes: maxBytes,
    );
    _pending.clear();
  }
}
