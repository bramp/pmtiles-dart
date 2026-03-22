import 'dart:math';

import 'package:meta/meta.dart';
import 'package:pool/pool.dart';

/// A simple async safe loading cache, with request joining.
// TODO(bramp): Bound the size of the cache, perhaps a LRU.
class LoadingCache<K, V> {
  LoadingCache(
    this._loader, {
    required this.capacity,
  }) : _pool = Pool(capacity, timeout: const Duration(seconds: 30));

  /// Max capacity in number of elements.
  final int capacity;

  /// Pool to bound the amount of concurrent work.
  final Pool _pool;

  /// Cache entries that have already been resolved.
  @visibleForTesting
  final Map<K, Future<V>> cache = {};

  /// Map of last read time.
  final Map<K, int> _lastRead = {};

  /// Fake "time". Increments on each read.
  int _time = 0;

  final Future<V> Function(K) _loader;

  Future<V> get(K key) async {
    _lastRead[key] = _time++;

    if (cache.containsKey(key)) {
      return cache[key]!;
    }

    final value = _pool.withResource(() {
      return _loader(key);
    });

    cache[key] = value;

    // The cache has gotten too big. Let's clean it up.
    if (cache.length > capacity) {
      final m = _lastRead.values.reduce(min);
      final k = _lastRead.entries
          .firstWhere((element) => element.value == m)
          .key;
      _lastRead.remove(k);
      cache.remove(k);
    }

    return value;
  }

  int get length {
    return cache.length;
  }
}
