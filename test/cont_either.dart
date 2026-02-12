import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.either (sequence)', () {
    test('returns first success', () {
      int? value;

      Cont.either<(), int>(
        Cont.of(10),
        Cont.of(20),
        policy: ContEitherPolicy.sequence(),
      ).run((), onThen: (val) => value = val);

      expect(value, 10);
    });

    test('falls back to second on first failure', () {
      int? value;

      Cont.either<(), int>(
        Cont.stop([ContError.capture('err')]),
        Cont.of(20),
        policy: ContEitherPolicy.sequence(),
      ).run((), onThen: (val) => value = val);

      expect(value, 20);
    });

    test('combines errors when both fail', () {
      List<ContError>? errors;

      Cont.either<(), int>(
        Cont.stop([ContError.capture('err1')]),
        Cont.stop([ContError.capture('err2')]),
        policy: ContEitherPolicy.sequence(),
      ).run((), onElse: (e) => errors = e);

      expect(errors!.length, 2);
      expect(errors![0].error, 'err1');
      expect(errors![1].error, 'err2');
    });

    test('does not execute second when first succeeds', () {
      bool secondCalled = false;

      Cont.either<(), int>(
        Cont.of(10),
        Cont.fromRun((runtime, observer) {
          secondCalled = true;
          observer.onThen(20);
        }),
        policy: ContEitherPolicy.sequence(),
      ).run(());

      expect(secondCalled, false);
    });
  });

  group('Cont.either (mergeWhenAll)', () {
    test('combines values when both succeed', () {
      int? value;

      Cont.either<(), int>(
        Cont.of(10),
        Cont.of(20),
        policy: ContEitherPolicy.mergeWhenAll(
          (a, b) => a + b,
        ),
      ).run((), onThen: (val) => value = val);

      expect(value, 30);
    });

    test('returns single success when one fails', () {
      int? value;

      Cont.either<(), int>(
        Cont.stop([ContError.capture('err')]),
        Cont.of(20),
        policy: ContEitherPolicy.mergeWhenAll(
          (a, b) => a + b,
        ),
      ).run((), onThen: (val) => value = val);

      expect(value, 20);
    });

    test('merges errors when both fail', () {
      List<ContError>? errors;

      Cont.either<(), int>(
        Cont.stop([ContError.capture('err1')]),
        Cont.stop([ContError.capture('err2')]),
        policy: ContEitherPolicy.mergeWhenAll(
          (a, b) => a + b,
        ),
      ).run((), onElse: (e) => errors = e);

      expect(errors!.length, 2);
      expect(errors![0].error, 'err1');
      expect(errors![1].error, 'err2');
    });
  });

  group('Cont.either (quitFast)', () {
    test('returns first success', () {
      int? value;

      Cont.either<(), int>(
        Cont.of(10),
        Cont.of(20),
        policy: ContEitherPolicy.quitFast(),
      ).run((), onThen: (val) => value = val);

      expect(value, 10);
    });

    test('terminates when both fail', () {
      List<ContError>? errors;

      Cont.either<(), int>(
        Cont.stop([ContError.capture('err1')]),
        Cont.stop([ContError.capture('err2')]),
        policy: ContEitherPolicy.quitFast(),
      ).run((), onElse: (e) => errors = e);

      expect(errors, isNotNull);
    });
  });

  group('Cont.or', () {
    test('wraps Cont.either as instance method', () {
      int? value1;
      int? value2;

      final left = Cont.stop<(), int>([
        ContError.capture('err'),
      ]);
      final right = Cont.of<(), int>(20);

      Cont.either<(), int>(
        left,
        right,
        policy: ContEitherPolicy.sequence(),
      ).run((), onThen: (val) => value1 = val);

      left
          .or(right, policy: ContEitherPolicy.sequence())
          .run((), onThen: (val) => value2 = val);

      expect(value1, value2);
    });

    test('supports Cont<E, Never> operands', () {
      int? value;

      final left = Cont.stop<(), Never>([
        ContError.capture('never err'),
      ]);
      final right = Cont.of<(), int>(20);

      Cont.either<(), int>(
        left.absurd(),
        right,
        policy: ContEitherPolicy.sequence(),
      ).run((), onThen: (val) => value = val);

      expect(value, 20);
    });
  });
}
