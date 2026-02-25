import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.either (sequence)', () {
    test('returns first success', () {
      int? value;

      Cont.either<(), String, String, String, int>(
        Cont.of(10),
        Cont.of(20),
        (a, b) => '$a, $b',
        policy: OkPolicy.sequence(),
      ).run((), onThen: (val) => value = val);

      expect(value, 10);
    });

    test('falls back to second on first failure', () {
      int? value;

      Cont.either<(), String, String, String, int>(
        Cont.error('err'),
        Cont.of(20),
        (a, b) => '$a, $b',
        policy: OkPolicy.sequence(),
      ).run((), onThen: (val) => value = val);

      expect(value, 20);
    });

    test('combines errors when both fail', () {
      String? error;

      Cont.either<(), String, String, String, int>(
        Cont.error('err1'),
        Cont.error('err2'),
        (a, b) => '$a, $b',
        policy: OkPolicy.sequence(),
      ).run((), onElse: (e) => error = e);

      expect(error, 'err1, err2');
    });

    test('does not execute second when first succeeds', () {
      bool secondCalled = false;

      Cont.either<(), String, String, String, int>(
        Cont.of(10),
        Cont.fromRun((runtime, observer) {
          secondCalled = true;
          observer.onThen(20);
        }),
        (a, b) => '$a, $b',
        policy: OkPolicy.sequence(),
      ).run(());

      expect(secondCalled, false);
    });
  });

  group('Cont.either (runAll)', () {
    test('combines values when both succeed', () {
      int? value;

      Cont.either<(), String, String, String, int>(
        Cont.of(10),
        Cont.of(20),
        (a, b) => '$a, $b',
        policy: OkPolicy.runAll(
          (a, b) => a + b,
          shouldFavorCrash: false,
        ),
      ).run((), onThen: (val) => value = val);

      expect(value, 30);
    });

    test('returns single success when one fails', () {
      int? value;

      Cont.either<(), String, String, String, int>(
        Cont.error('err'),
        Cont.of(20),
        (a, b) => '$a, $b',
        policy: OkPolicy.runAll(
          (a, b) => a + b,
          shouldFavorCrash: false,
        ),
      ).run((), onThen: (val) => value = val);

      expect(value, 20);
    });

    test('merges errors when both fail', () {
      String? error;

      Cont.either<(), String, String, String, int>(
        Cont.error('err1'),
        Cont.error('err2'),
        (a, b) => '$a, $b',
        policy: OkPolicy.runAll(
          (a, b) => a + b,
          shouldFavorCrash: false,
        ),
      ).run((), onElse: (e) => error = e);

      expect(error, 'err1, err2');
    });
  });

  group('Cont.either (quitFast)', () {
    test('returns first success', () {
      int? value;

      Cont.either<(), String, String, String, int>(
        Cont.of(10),
        Cont.of(20),
        (a, b) => '$a, $b',
        policy: OkPolicy.quitFast(),
      ).run((), onThen: (val) => value = val);

      expect(value, 10);
    });

    test('terminates when both fail', () {
      String? error;

      Cont.either<(), String, String, String, int>(
        Cont.error('err1'),
        Cont.error('err2'),
        (a, b) => '$a, $b',
        policy: OkPolicy.quitFast(),
      ).run((), onElse: (e) => error = e);

      expect(error, isNotNull);
    });
  });

  group('Cont.or', () {
    test('wraps Cont.either as instance method', () {
      int? value1;
      int? value2;

      final left = Cont.error<(), String, int>('err');
      final right = Cont.of<(), String, int>(20);

      Cont.either<(), String, String, String, int>(
        left,
        right,
        (a, b) => '$a, $b',
        policy: OkPolicy.sequence(),
      ).run((), onThen: (val) => value1 = val);

      left
          .or(
            right,
            (a, b) => '$a, $b',
            policy: OkPolicy.sequence(),
          )
          .run((), onThen: (val) => value2 = val);

      expect(value1, value2);
    });

    test('supports Cont<E, F, Never> operands', () {
      int? value;

      final left = Cont.error<(), String, Never>('never err');
      final right = Cont.of<(), String, int>(20);

      left
          .thenAbsurd<int>()
          .or(
            right,
            (a, b) => '$a, $b',
            policy: OkPolicy.sequence(),
          )
          .run((), onThen: (val) => value = val);

      expect(value, 20);
    });
  });
}
