import 'package:pmtiles/src/loading_cache.dart';
import 'package:test/test.dart';

void main() {
  group('LoadingCache', () {
    test('cache', () async {
      final cache = LoadingCache<int, int>(
        (key) => Future.value(key),
        capacity: 8,
      );

      expect(cache.length, equals(0));

      var v = cache.get(1);
      expect(cache.length, equals(1));
      expect(await v, equals(1));

      v = cache.get(1);
      expect(cache.length, equals(1));
      expect(await v, equals(1));

      v = cache.get(2);
      expect(cache.length, equals(2));
      expect(await v, equals(2));
    });

    test('cache (microtask)', () async {
      final cache = LoadingCache<int, int>(
        (key) => Future.microtask(() => key),
        capacity: 8,
      );

      expect(cache.length, equals(0));

      var v = cache.get(1);
      expect(cache.length, equals(1));
      expect(await v, equals(1));

      v = cache.get(1);
      expect(cache.length, equals(1));
      expect(await v, equals(1));

      v = cache.get(2);
      expect(cache.length, equals(2));
      expect(await v, equals(2));
    });

    test('cache (lots of concurrent identical request)', () async {
      int loads = 0;

      final cache = LoadingCache<int, int>(
        (key) {
          loads++;
          return Future.microtask(() => key);
        },
        capacity: 8,
      );

      expect(cache.length, equals(0));

      final results =
          await Future.wait(List.generate(1000, (index) => cache.get(1)));
      expect(results, everyElement(equals(1)));
      expect(cache.length, equals(1));

      expect(loads, equals(1));
    });

    test('cache (lots of concurrent different)', () async {
      int loads = 0;

      final cache = LoadingCache<int, int>(
        (key) {
          loads++;
          return Future.microtask(() => key);
        },
        capacity: 8,
      );

      expect(cache.length, equals(0));

      const n = 1000;
      final results =
          await Future.wait(List.generate(n, (index) => cache.get(index)));
      expect(results, List.generate(n, (index) => index));
      expect(cache.length, equals(8));
      expect(loads, equals(n));

      expect(cache.cache.keys.toSet(),
          List.generate(8, (index) => n - 8 + index).toSet());
    });
  });
}
