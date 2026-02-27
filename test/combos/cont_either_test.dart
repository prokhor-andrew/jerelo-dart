import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.either (sequence)', () {
    test('returns first success', () {
      int? result;

      Cont.either<(), String, String, String, int>(
        Cont.of(42),
        Cont.of(99),
        (a, b) => '$a+$b',
        policy: OkPolicy.sequence(),
      ).run((), onThen: (v) => result = v);

      expect(result, equals(42));
    });

    test('falls back to second on first failure', () {
      int? result;

      Cont.either<(), String, String, String, int>(
        Cont.error('first failed'),
        Cont.of(99),
        (a, b) => '$a+$b',
        policy: OkPolicy.sequence(),
      ).run((), onThen: (v) => result = v);

      expect(result, equals(99));
    });

    test('combines errors when both fail', () {
      String? error;

      Cont.either<(), String, String, String, int>(
        Cont.error('first'),
        Cont.error('second'),
        (a, b) => '$a+$b',
        policy: OkPolicy.sequence(),
      ).run((), onElse: (e) => error = e);

      expect(error, equals('first+second'));
    });

    test('does not execute second when first succeeds', () {
      bool secondExecuted = false;

      Cont.either<(), String, String, String, int>(
        Cont.of(42),
        Cont.fromRun((runtime, observer) {
          secondExecuted = true;
          observer.onThen(0);
        }),
        (a, b) => '$a+$b',
        policy: OkPolicy.sequence(),
      ).run(());

      expect(secondExecuted, isFalse);
    });
  });

  group('Cont.either (runAll)', () {
    test('combines values when both succeed', () {
      int? result;

      Cont.either<(), String, String, String, int>(
        Cont.of(1),
        Cont.of(2),
        (a, b) => '$a+$b',
        policy: OkPolicy.runAll(
          (a, b) => a + b,
          shouldFavorCrash: false,
        ),
      ).run((), onThen: (v) => result = v);

      expect(result, equals(3));
    });

    test('returns single success when one fails', () {
      int? result;

      Cont.either<(), String, String, String, int>(
        Cont.error('failed'),
        Cont.of(42),
        (a, b) => '$a+$b',
        policy: OkPolicy.runAll(
          (a, b) => a + b,
          shouldFavorCrash: false,
        ),
      ).run((), onThen: (v) => result = v);

      expect(result, equals(42));
    });

    test('merges errors when both fail', () {
      String? error;

      Cont.either<(), String, String, String, int>(
        Cont.error('left'),
        Cont.error('right'),
        (a, b) => '$a+$b',
        policy: OkPolicy.runAll(
          (a, b) => a + b,
          shouldFavorCrash: false,
        ),
      ).run((), onElse: (e) => error = e);

      expect(error, equals('left+right'));
    });
  });

  group('Cont.either (quitFast)', () {
    test('returns first success', () {
      int? result;

      Cont.either<(), String, String, String, int>(
        Cont.of(42),
        Cont.of(99),
        (a, b) => '$a+$b',
        policy: OkPolicy.quitFast(),
      ).run((), onThen: (v) => result = v);

      expect(result, isNotNull);
    });

    test('terminates when both fail', () {
      String? error;

      Cont.either<(), String, String, String, int>(
        Cont.error('first'),
        Cont.error('second'),
        (a, b) => '$a+$b',
        policy: OkPolicy.quitFast(),
      ).run((), onElse: (e) => error = e);

      expect(error, isNotNull);
    });
  });

  group('Cont.or', () {
    test('wraps Cont.either as instance method', () {
      int? result;

      Cont.error<(), String, int>('first failed')
          .or(Cont.of(42), (a, b) => '$a+$b',
              policy: OkPolicy.sequence())
          .run((), onThen: (v) => result = v);

      expect(result, equals(42));
    });

    test('supports Cont<E, F, Never> operands', () {
      int? result;

      Cont.error<(), String, int>('failed')
          .or(
        Cont.of<(), Never, int>(42),
        (a, b) => '$a+$b',
        policy: OkPolicy.sequence(),
      )
          .run((), onThen: (v) => result = v);

      expect(result, equals(42));
    });
  });
}
