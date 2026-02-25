import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.all (sequence)', () {
    test('collects all values in order', () {
      List<int>? value;

      Cont.all<(), String, int>(
        [Cont.of(1), Cont.of(2), Cont.of(3)],
        policy: OkPolicy.sequence(),
      ).run((), onThen: (val) => value = val);

      expect(value, [1, 2, 3]);
    });

    test('executes sequentially', () {
      final order = <int>[];
      List<int>? value;

      Cont.all<(), String, int>([
        Cont.fromRun((runtime, observer) {
          order.add(1);
          observer.onThen(1);
        }),
        Cont.fromRun((runtime, observer) {
          order.add(2);
          observer.onThen(2);
        }),
        Cont.fromRun((runtime, observer) {
          order.add(3);
          observer.onThen(3);
        }),
      ], policy: OkPolicy.sequence()).run(
        (),
        onThen: (val) => value = val,
      );

      expect(order, [1, 2, 3]);
      expect(value, [1, 2, 3]);
    });

    test('stops at first failure', () {
      String? error;
      bool thirdCalled = false;

      Cont.all<(), String, int>(
        [
          Cont.of(1),
          Cont.error('err'),
          Cont.fromRun((runtime, observer) {
            thirdCalled = true;
            observer.onThen(3);
          }),
        ],
        policy: OkPolicy.sequence(),
      ).run((), onElse: (e) => error = e);

      expect(error, 'err');
      expect(thirdCalled, false);
    });

    test('succeeds with empty list', () {
      List<int>? value;

      Cont.all<(), String, int>(
        [],
        policy: OkPolicy.sequence(),
      ).run((), onThen: (val) => value = val);

      expect(value, isEmpty);
    });
  });

  group('Cont.all (runAll)', () {
    test('collects all values', () {
      List<int>? value;

      Cont.all<(), String, int>(
        [Cont.of(1), Cont.of(2), Cont.of(3)],
        policy: OkPolicy.runAll(
          (a, b) => '$a, $b',
          shouldFavorCrash: false,
        ),
      ).run((), onThen: (val) => value = val);

      expect(value, [1, 2, 3]);
    });

    test('combines errors from multiple failures', () {
      String? error;

      Cont.all<(), String, int>(
        [
          Cont.error('err1'),
          Cont.of(2),
          Cont.error('err3'),
        ],
        policy: OkPolicy.runAll(
          (a, b) => '$a, $b',
          shouldFavorCrash: false,
        ),
      ).run((), onElse: (e) => error = e);

      expect(error, 'err1, err3');
    });
  });

  group('Cont.all (quitFast)', () {
    test('collects all values', () {
      List<int>? value;

      Cont.all<(), String, int>(
        [Cont.of(1), Cont.of(2), Cont.of(3)],
        policy: OkPolicy.quitFast(),
      ).run((), onThen: (val) => value = val);

      expect(value, [1, 2, 3]);
    });

    test('terminates on first failure', () {
      String? error;

      Cont.all<(), String, int>(
        [
          Cont.of(1),
          Cont.error('err'),
          Cont.of(3),
        ],
        policy: OkPolicy.quitFast(),
      ).run((), onElse: (e) => error = e);

      expect(error, 'err');
    });
  });

  group('Cont.all shared', () {
    test('supports multiple runs', () {
      var callCount = 0;
      final cont = Cont.all<(), String, int>([
        Cont.fromRun((runtime, observer) {
          callCount++;
          observer.onThen(callCount);
        }),
      ], policy: OkPolicy.sequence());

      List<int>? value1;
      cont.run((), onThen: (val) => value1 = val);
      expect(value1, [1]);
      expect(callCount, 1);

      List<int>? value2;
      cont.run((), onThen: (val) => value2 = val);
      expect(value2, [2]);
      expect(callCount, 2);
    });
  });
}
