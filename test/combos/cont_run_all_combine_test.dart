import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

/// Items that report when the test tells them to.
final class _Items<F, A> {
  final List<SafeObserver<F, A>?> observers;
  late final List<Cont<(), F, A>> conts;

  _Items(int count) : observers = List.filled(count, null) {
    conts = List.generate(count, (i) {
      return Cont.fromRun<(), F, A>((_, observer) {
        observers[i] = observer;
        return () {};
      });
    });
  }
}

Object? _errorOf(ContCrash? crash) {
  return switch (crash) {
    NormalCrash(error: final error) => error,
    _ => crash,
  };
}

void main() {
  group(
      'runAll: a throwing combine is the combinator\'s crash',
      () {
    for (final shouldFavorCrash in [true, false]) {
      for (final order in [
        [0, 1, 2],
        [0, 2, 1],
      ]) {
        test(
            'all, shouldFavorCrash: $shouldFavorCrash, '
            'order $order', () {
          final items = _Items<String, int>(3);
          ContCrash? crash;
          String? error;
          Cont.all(
            items.conts,
            policy: OkPolicy.runAll<String>(
              (acc, e) {
                if (e == 'e1') throw 'combine failed';
                return '$acc+$e';
              },
              shouldFavorCrash: shouldFavorCrash,
            ),
          ).run(
            (),
            onCrash: (c) => crash = c,
            onElse: (e) => error = e,
          );
          for (final i in order) {
            expect(crash, isNull);
            items.observers[i]!.onElse('e$i');
          }

          expect(crash, isA<NormalCrash>());
          expect(_errorOf(crash), equals('combine failed'));
          expect(error, isNull);
        });

        test(
            'any, shouldFavorCrash: $shouldFavorCrash, '
            'order $order', () {
          final items = _Items<String, int>(3);
          ContCrash? crash;
          int? value;
          Cont.any(
            items.conts,
            policy: OkPolicy.runAll<int>(
              (acc, v) {
                if (v == 1) throw 'combine failed';
                return acc + v;
              },
              shouldFavorCrash: shouldFavorCrash,
            ),
          ).run(
            (),
            onCrash: (c) => crash = c,
            onThen: (v) => value = v,
          );
          for (final i in order) {
            items.observers[i]!.onThen(i);
          }

          expect(_errorOf(crash), equals('combine failed'));
          expect(value, isNull);
        });

        test(
            'converge, shouldFavorElse: $shouldFavorCrash, '
            'order $order', () {
          final items = _Items<String, int>(3);
          ContCrash? crash;
          int? value;
          Cont.converge(
            items.conts,
            policy: CrashPolicy.runAll<String, int>(
              shouldFavorElse: shouldFavorCrash,
              combineElseVals: (a, b) => '$a$b',
              combineThenVals: (acc, v) {
                if (v == 1) throw 'combine failed';
                return acc + v;
              },
            ),
          ).run(
            (),
            onCrash: (c) => crash = c,
            onThen: (v) => value = v,
          );
          for (final i in order) {
            items.observers[i]!.onThen(i);
          }

          expect(_errorOf(crash), equals('combine failed'));
          expect(value, isNull);
        });
      }
    }

    test('the result waits until every item has finished',
        () {
      final items = _Items<String, int>(3);
      ContCrash? crash;
      Cont.all(
        items.conts,
        policy: OkPolicy.runAll<String>(
          (acc, e) => throw 'combine failed',
          shouldFavorCrash: true,
        ),
      ).run((), onCrash: (c) => crash = c);
      items.observers[0]!.onElse('e0');
      items.observers[1]!.onElse('e1');

      expect(crash, isNull);

      items.observers[2]!.onElse('e2');

      expect(_errorOf(crash), equals('combine failed'));
    });

    test('combine stops being called after it threw', () {
      final items = _Items<String, int>(4);
      var calls = 0;
      Cont.all(
        items.conts,
        policy: OkPolicy.runAll<String>(
          (acc, e) {
            calls += 1;
            throw 'combine failed';
          },
          shouldFavorCrash: true,
        ),
      ).run(());
      for (var i = 0; i < 4; i++) {
        items.observers[i]!.onElse('e$i');
      }

      expect(calls, equals(1));
    });

    test('the combine crash wins over items that crashed',
        () {
      final items = _Items<String, int>(3);
      ContCrash? crash;
      Cont.all(
        items.conts,
        policy: OkPolicy.runAll<String>(
          (acc, e) => throw 'combine failed',
          shouldFavorCrash: true,
        ),
      ).run((), onCrash: (c) => crash = c);
      items.observers[0]!.onElse('e0');
      items.observers[1]!.onElse('e1');
      Cont.fromRun<(), String, int>((_, __) {
        throw 'item crashed';
      }).run(
        (),
        onCrash: (c) => items.observers[2]!.onCrash(c),
      );

      expect(_errorOf(crash), equals('combine failed'));
    });

    test(
        'items that crashed without a combine failure are collected',
        () {
      final items = _Items<String, int>(3);
      ContCrash? crash;
      Cont.all(
        items.conts,
        policy: OkPolicy.runAll<String>(
          (acc, e) => '$acc+$e',
          shouldFavorCrash: true,
        ),
      ).run((), onCrash: (c) => crash = c);
      items.observers[0]!.onElse('e0');
      Cont.fromRun<(), String, int>((_, __) {
        throw 'item crashed';
      }).run(
        (),
        onCrash: (c) => items.observers[1]!.onCrash(c),
      );
      items.observers[2]!.onElse('e2');

      expect(crash, isA<CollectedCrash>());
      expect(
        (crash as CollectedCrash).crashes.keys,
        equals([1]),
      );
    });

    test(
        'both and either report a throwing combine the same way',
        () {
      ContCrash? bothCrash;
      ContCrash? eitherCrash;
      ContCrash? coalesceCrash;
      Cont.both(
        Cont.error<(), String, int>('a'),
        Cont.error<(), String, int>('b'),
        (x, y) => x + y,
        policy: OkPolicy.runAll<String>(
          (a, b) => throw 'combine failed',
          shouldFavorCrash: false,
        ),
      ).run((), onCrash: (c) => bothCrash = c);
      Cont.either(
        Cont.of<(), String, int>(1),
        Cont.of<(), String, int>(2),
        (a, b) => '$a$b',
        policy: OkPolicy.runAll<int>(
          (a, b) => throw 'combine failed',
          shouldFavorCrash: false,
        ),
      ).run((), onCrash: (c) => eitherCrash = c);
      Cont.coalesce(
        Cont.of<(), String, int>(1),
        Cont.of<(), String, int>(2),
        policy: CrashPolicy.runAll<String, int>(
          shouldFavorElse: false,
          combineElseVals: (a, b) => '$a$b',
          combineThenVals: (a, b) => throw 'combine failed',
        ),
      ).run((), onCrash: (c) => coalesceCrash = c);

      expect(_errorOf(bothCrash), equals('combine failed'));
      expect(
          _errorOf(eitherCrash), equals('combine failed'));
      expect(_errorOf(coalesceCrash),
          equals('combine failed'));
    });
  });
}
