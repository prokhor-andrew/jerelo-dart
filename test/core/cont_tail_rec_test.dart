import 'dart:async';

import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.tailRecM', () {
    test('loops until done', () {
      int? result;

      Cont.tailRecM<(), String, int, int>(0, (n) {
        return Cont.of(
          n >= 10
              ? TailRec.done(n * 2)
              : TailRec.next(n + 1),
        );
      }).run((), onThen: (v) => result = v);

      expect(result, equals(20));
    });

    test('is stack safe for synchronous steps', () {
      int? result;

      Cont.tailRecM<(), String, int, int>(0, (n) {
        return Cont.of(
          n >= 100000
              ? TailRec.done(n)
              : TailRec.next(n + 1),
        );
      }).run((), onThen: (v) => result = v);

      expect(result, equals(100000));
    });

    test('supports asynchronous steps', () async {
      final completer = Completer<int>();

      Cont.tailRecM<(), String, int, int>(0, (n) {
        return Cont.fromRun((runtime, observer) {
          Timer(Duration.zero, () {
            observer.onThen(
              n >= 3
                  ? TailRec.done(n)
                  : TailRec.next(n + 1),
            );
          });
        });
      }).run((), onThen: completer.complete);

      expect(await completer.future, equals(3));
    });

    test('ends on else', () {
      String? error;
      var steps = 0;

      Cont.tailRecM<(), String, int, int>(0, (n) {
        steps++;
        return n == 2
            ? Cont.error('stop at $n')
            : Cont.of(TailRec.next(n + 1));
      }).run((), onElse: (e) => error = e);

      expect(error, equals('stop at 2'));
      expect(steps, equals(3));
    });

    test('ends on crash', () {
      ContCrash? crash;

      Cont.tailRecM<(), String, int, int>(0, (n) {
        return Cont.of<(), String, int>(n)
            .thenDo<TailRec<int, int>>((_) {
          throw 'boom';
        });
      }).run((), onCrash: (c) => crash = c);

      expect(crash, isA<NormalCrash>());
      expect((crash! as NormalCrash).error, equals('boom'));
    });

    test('a throw from step becomes a crash', () {
      ContCrash? crash;

      Cont.tailRecM<(), String, int, int>(0, (n) {
        throw 'step failed';
      }).run((), onCrash: (c) => crash = c);

      expect((crash! as NormalCrash).error,
          equals('step failed'));
    });

    test('each run starts from the initial state', () {
      final results = <int>[];

      final cont =
          Cont.tailRecM<(), String, int, int>(0, (n) {
        return Cont.of(
          n >= 5 ? TailRec.done(n) : TailRec.next(n + 1),
        );
      });

      cont.run((), onThen: results.add);
      cont.run((), onThen: results.add);

      expect(results, equals([5, 5]));
    });

    test('reads the environment in each step', () {
      int? result;

      Cont.tailRecM<int, String, int, int>(0, (n) {
        return Cont.askThen<int, String>().thenMap((limit) {
          return n >= limit
              ? TailRec<int, int>.done(n)
              : TailRec<int, int>.next(n + 1);
        });
      }).run(7, onThen: (v) => result = v);

      expect(result, equals(7));
    });
  });

  group('TailRec', () {
    test('next steps with equal states are equal', () {
      const a = TailRec<int, String>.next(1);
      final b = TailRec<int, String>.next(1);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(
          a, isNot(equals(TailRec<int, String>.next(2))));
    });

    test('done steps with equal results are equal', () {
      const a = TailRec<int, String>.done('x');
      final b = TailRec<int, String>.done('x');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(
          a, isNot(equals(TailRec<int, String>.done('y'))));
    });

    test('next and done are never equal', () {
      const next = TailRec<int, int>.next(1);
      const done = TailRec<int, int>.done(1);

      expect(next, isNot(equals(done)));
      expect(done, isNot(equals(next)));
    });

    test('next and done expose their values', () {
      const next = TailRec<int, String>.next(1);
      const done = TailRec<int, String>.done('x');

      expect(next, isA<TailRecNext<int, String>>());
      expect((next as TailRecNext<int, String>).state, 1);
      expect(done, isA<TailRecDone<int, String>>());
      expect(
          (done as TailRecDone<int, String>).result, 'x');
    });
  });
}
