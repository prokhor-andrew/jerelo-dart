import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.both (sequence)', () {
    test('combines two values', () {
      String? value;

      Cont.both<(), String, int, String, String>(
        Cont.of(10),
        Cont.of('hello'),
        (a, b) => '$b: $a',
        policy: OkPolicy.sequence(),
      ).run((), onThen: (val) => value = val);

      expect(value, 'hello: 10');
    });

    test('executes sequentially', () {
      final order = <String>[];
      int? value;

      Cont.both<(), String, int, int, int>(
        Cont.fromRun((runtime, observer) {
          order.add('left');
          observer.onThen(1);
        }),
        Cont.fromRun((runtime, observer) {
          order.add('right');
          observer.onThen(2);
        }),
        (a, b) => a + b,
        policy: OkPolicy.sequence(),
      ).run((), onThen: (val) => value = val);

      expect(order, ['left', 'right']);
      expect(value, 3);
    });

    test('terminates on left failure', () {
      String? error;
      bool rightCalled = false;

      Cont.both<(), String, int, int, int>(
        Cont.error('left err'),
        Cont.fromRun((runtime, observer) {
          rightCalled = true;
          observer.onThen(2);
        }),
        (a, b) => a + b,
        policy: OkPolicy.sequence(),
      ).run((), onElse: (e) => error = e);

      expect(error, 'left err');
      expect(rightCalled, false);
    });

    test('terminates on right failure', () {
      String? error;

      Cont.both<(), String, int, int, int>(
        Cont.of(1),
        Cont.error('right err'),
        (a, b) => a + b,
        policy: OkPolicy.sequence(),
      ).run((), onElse: (e) => error = e);

      expect(error, 'right err');
    });
  });

  group('Cont.both (runAll)', () {
    test('combines two values', () {
      int? value;

      Cont.both<(), String, int, int, int>(
        Cont.of(10),
        Cont.of(20),
        (a, b) => a + b,
        policy: OkPolicy.runAll(
          (a, b) => '$a, $b',
          shouldFavorCrash: false,
        ),
      ).run((), onThen: (val) => value = val);

      expect(value, 30);
    });

    test('merges errors when both fail', () {
      String? error;

      Cont.both<(), String, int, int, int>(
        Cont.error('err1'),
        Cont.error('err2'),
        (a, b) => a + b,
        policy: OkPolicy.runAll(
          (a, b) => '$a, $b',
          shouldFavorCrash: false,
        ),
      ).run((), onElse: (e) => error = e);

      expect(error, 'err1, err2');
    });

    test('terminates when only left fails', () {
      String? error;

      Cont.both<(), String, int, int, int>(
        Cont.error('left err'),
        Cont.of(2),
        (a, b) => a + b,
        policy: OkPolicy.runAll(
          (a, b) => '$a, $b',
          shouldFavorCrash: false,
        ),
      ).run((), onElse: (e) => error = e);

      expect(error, 'left err');
    });
  });

  group('Cont.both (quitFast)', () {
    test('combines two values', () {
      int? value;

      Cont.both<(), String, int, int, int>(
        Cont.of(10),
        Cont.of(20),
        (a, b) => a + b,
        policy: OkPolicy.quitFast(),
      ).run((), onThen: (val) => value = val);

      expect(value, 30);
    });

    test('terminates on first failure', () {
      String? error;

      Cont.both<(), String, int, int, int>(
        Cont.error('err1'),
        Cont.of(2),
        (a, b) => a + b,
        policy: OkPolicy.quitFast(),
      ).run((), onElse: (e) => error = e);

      expect(error, 'err1');
    });
  });

  group('Cont.and', () {
    test('wraps Cont.both as instance method', () {
      String? value1;
      String? value2;

      final left = Cont.of<(), String, int>(10);
      final right = Cont.of<(), String, String>('hello');

      Cont.both<(), String, int, String, String>(
        left,
        right,
        (a, b) => '$b: $a',
        policy: OkPolicy.sequence(),
      ).run((), onThen: (val) => value1 = val);

      left
          .and(
        right,
        (a, b) => '$b: $a',
        policy: OkPolicy.sequence(),
      )
          .run((), onThen: (val) => value2 = val);

      expect(value1, value2);
    });

    test('supports multiple policies', () {
      int? seqVal;
      int? mergeVal;
      int? fastVal;

      final left = Cont.of<(), String, int>(1);
      final right = Cont.of<(), String, int>(2);

      left
          .and(
        right,
        (a, b) => a + b,
        policy: OkPolicy.sequence(),
      )
          .run((), onThen: (val) => seqVal = val);

      left
          .and(
        right,
        (a, b) => a + b,
        policy: OkPolicy.runAll(
          (a, b) => '$a, $b',
          shouldFavorCrash: false,
        ),
      )
          .run((), onThen: (val) => mergeVal = val);

      left
          .and(
        right,
        (a, b) => a + b,
        policy: OkPolicy.quitFast(),
      )
          .run((), onThen: (val) => fastVal = val);

      expect(seqVal, 3);
      expect(mergeVal, 3);
      expect(fastVal, 3);
    });

    test('supports Cont<E, F, Never> operands', () {
      String? error;

      final left =
          Cont.error<(), String, Never>('never err');
      final right = Cont.of<(), String, int>(2);

      left
          .and<int, int>(
        right,
        (a, b) => b,
        policy: OkPolicy.sequence(),
      )
          .run((), onElse: (e) => error = e);

      expect(error, 'never err');
    });
  });
}
