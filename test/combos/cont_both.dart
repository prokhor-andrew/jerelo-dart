import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.both (sequence)', () {
    test('combines two values', () {
      String? value;

      Cont.both<(), int, String, String>(
        Cont.of(10),
        Cont.of('hello'),
        (a, b) => '$b: $a',
        policy: ContBothPolicy.sequence(),
      ).run((), onThen: (val) => value = val);

      expect(value, 'hello: 10');
    });

    test('executes sequentially', () {
      final order = <String>[];
      int? value;

      Cont.both<(), int, int, int>(
        Cont.fromRun((runtime, observer) {
          order.add('left');
          observer.onThen(1);
        }),
        Cont.fromRun((runtime, observer) {
          order.add('right');
          observer.onThen(2);
        }),
        (a, b) => a + b,
        policy: ContBothPolicy.sequence(),
      ).run((), onThen: (val) => value = val);

      expect(order, ['left', 'right']);
      expect(value, 3);
    });

    test('terminates on left failure', () {
      List<ContError>? errors;
      bool rightCalled = false;

      Cont.both<(), int, int, int>(
        Cont.stop([ContError.capture('left err')]),
        Cont.fromRun((runtime, observer) {
          rightCalled = true;
          observer.onThen(2);
        }),
        (a, b) => a + b,
        policy: ContBothPolicy.sequence(),
      ).run((), onElse: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'left err');
      expect(rightCalled, false);
    });

    test('terminates on right failure', () {
      List<ContError>? errors;

      Cont.both<(), int, int, int>(
        Cont.of(1),
        Cont.stop([ContError.capture('right err')]),
        (a, b) => a + b,
        policy: ContBothPolicy.sequence(),
      ).run((), onElse: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'right err');
    });
  });

  group('Cont.both (mergeWhenAll)', () {
    test('combines two values', () {
      int? value;

      Cont.both<(), int, int, int>(
        Cont.of(10),
        Cont.of(20),
        (a, b) => a + b,
        policy: ContBothPolicy.mergeWhenAll(),
      ).run((), onThen: (val) => value = val);

      expect(value, 30);
    });

    test('merges errors when both fail', () {
      List<ContError>? errors;

      Cont.both<(), int, int, int>(
        Cont.stop([ContError.capture('err1')]),
        Cont.stop([ContError.capture('err2')]),
        (a, b) => a + b,
        policy: ContBothPolicy.mergeWhenAll(),
      ).run((), onElse: (e) => errors = e);

      expect(errors!.length, 2);
      expect(errors![0].error, 'err1');
      expect(errors![1].error, 'err2');
    });

    test('terminates when only left fails', () {
      List<ContError>? errors;

      Cont.both<(), int, int, int>(
        Cont.stop([ContError.capture('left err')]),
        Cont.of(2),
        (a, b) => a + b,
        policy: ContBothPolicy.mergeWhenAll(),
      ).run((), onElse: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'left err');
    });
  });

  group('Cont.both (quitFast)', () {
    test('combines two values', () {
      int? value;

      Cont.both<(), int, int, int>(
        Cont.of(10),
        Cont.of(20),
        (a, b) => a + b,
        policy: ContBothPolicy.quitFast(),
      ).run((), onThen: (val) => value = val);

      expect(value, 30);
    });

    test('terminates on first failure', () {
      List<ContError>? errors;

      Cont.both<(), int, int, int>(
        Cont.stop([ContError.capture('err1')]),
        Cont.of(2),
        (a, b) => a + b,
        policy: ContBothPolicy.quitFast(),
      ).run((), onElse: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'err1');
    });
  });

  group('Cont.and', () {
    test('wraps Cont.both as instance method', () {
      String? value1;
      String? value2;

      final left = Cont.of<(), int>(10);
      final right = Cont.of<(), String>('hello');

      Cont.both<(), int, String, String>(
        left,
        right,
        (a, b) => '$b: $a',
        policy: ContBothPolicy.sequence(),
      ).run((), onThen: (val) => value1 = val);

      left
          .and(
            right,
            (a, b) => '$b: $a',
            policy: ContBothPolicy.sequence(),
          )
          .run((), onThen: (val) => value2 = val);

      expect(value1, value2);
    });

    test('supports multiple policies', () {
      int? seqVal;
      int? mergeVal;
      int? fastVal;

      final left = Cont.of<(), int>(1);
      final right = Cont.of<(), int>(2);

      left
          .and(
            right,
            (a, b) => a + b,
            policy: ContBothPolicy.sequence(),
          )
          .run((), onThen: (val) => seqVal = val);

      left
          .and(
            right,
            (a, b) => a + b,
            policy: ContBothPolicy.mergeWhenAll(),
          )
          .run((), onThen: (val) => mergeVal = val);

      left
          .and(
            right,
            (a, b) => a + b,
            policy: ContBothPolicy.quitFast(),
          )
          .run((), onThen: (val) => fastVal = val);

      expect(seqVal, 3);
      expect(mergeVal, 3);
      expect(fastVal, 3);
    });

    test('supports Cont<E, Never> operands', () {
      List<ContError>? errors;

      final left = Cont.stop<(), Never>([
        ContError.capture('never err'),
      ]);
      final right = Cont.of<(), int>(2);

      left
          .and<int, int>(
            right,
            (a, b) => b,
            policy: ContBothPolicy.sequence(),
          )
          .run((), onElse: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'never err');
    });
  });
}
