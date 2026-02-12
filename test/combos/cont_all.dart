import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.all (sequence)', () {
    test('collects all values in order', () {
      List<int>? value;

      Cont.all<(), int>(
        [Cont.of(1), Cont.of(2), Cont.of(3)],
        policy: ContBothPolicy.sequence(),
      ).run((), onThen: (val) => value = val);

      expect(value, [1, 2, 3]);
    });

    test('executes sequentially', () {
      final order = <int>[];
      List<int>? value;

      Cont.all<(), int>([
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
      ], policy: ContBothPolicy.sequence()).run(
        (),
        onThen: (val) => value = val,
      );

      expect(order, [1, 2, 3]);
      expect(value, [1, 2, 3]);
    });

    test('stops at first failure', () {
      List<ContError>? errors;
      bool thirdCalled = false;

      Cont.all<(), int>(
        [
          Cont.of(1),
          Cont.stop([ContError.capture('err')]),
          Cont.fromRun((runtime, observer) {
            thirdCalled = true;
            observer.onThen(3);
          }),
        ],
        policy: ContBothPolicy.sequence(),
      ).run((), onElse: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'err');
      expect(thirdCalled, false);
    });

    test('succeeds with empty list', () {
      List<int>? value;

      Cont.all<(), int>(
        [],
        policy: ContBothPolicy.sequence(),
      ).run((), onThen: (val) => value = val);

      expect(value, isEmpty);
    });
  });

  group('Cont.all (mergeWhenAll)', () {
    test('collects all values', () {
      List<int>? value;

      Cont.all<(), int>(
        [Cont.of(1), Cont.of(2), Cont.of(3)],
        policy: ContBothPolicy.mergeWhenAll(),
      ).run((), onThen: (val) => value = val);

      expect(value, [1, 2, 3]);
    });

    test('merges errors from multiple failures', () {
      List<ContError>? errors;

      Cont.all<(), int>(
        [
          Cont.stop([ContError.capture('err1')]),
          Cont.of(2),
          Cont.stop([ContError.capture('err3')]),
        ],
        policy: ContBothPolicy.mergeWhenAll(),
      ).run((), onElse: (e) => errors = e);

      expect(errors!.length, 2);
      expect(errors![0].error, 'err1');
      expect(errors![1].error, 'err3');
    });
  });

  group('Cont.all (quitFast)', () {
    test('collects all values', () {
      List<int>? value;

      Cont.all<(), int>(
        [Cont.of(1), Cont.of(2), Cont.of(3)],
        policy: ContBothPolicy.quitFast(),
      ).run((), onThen: (val) => value = val);

      expect(value, [1, 2, 3]);
    });

    test('terminates on first failure', () {
      List<ContError>? errors;

      Cont.all<(), int>(
        [
          Cont.of(1),
          Cont.stop([ContError.capture('err')]),
          Cont.of(3),
        ],
        policy: ContBothPolicy.quitFast(),
      ).run((), onElse: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'err');
    });
  });

  group('Cont.all shared', () {
    test('supports multiple runs', () {
      var callCount = 0;
      final cont = Cont.all<(), int>([
        Cont.fromRun((runtime, observer) {
          callCount++;
          observer.onThen(callCount);
        }),
      ], policy: ContBothPolicy.sequence());

      List<int>? value1;
      cont.run((), onThen: (val) => value1 = val);
      expect(value1, [1]);
      expect(callCount, 1);

      List<int>? value2;
      cont.run((), onThen: (val) => value2 = val);
      expect(value2, [2]);
      expect(callCount, 2);
    });

    test('makes defensive copy of list', () {
      final list = <Cont<(), int>>[Cont.of(1), Cont.of(2)];
      final cont = Cont.all<(), int>(
        list,
        policy: ContBothPolicy.sequence(),
      );

      list.add(Cont.of(3));

      List<int>? value;
      cont.run((), onThen: (val) => value = val);

      expect(value, [1, 2]); // original list, not mutated
    });
  });
}
