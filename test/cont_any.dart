import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.any (sequence)', () {
    test('returns first success', () {
      int? value;

      Cont.any<(), int>(
        [
          Cont.terminate([ContError.capture('err')]),
          Cont.of(20),
          Cont.of(30),
        ],
        policy: ContEitherPolicy.sequence(),
      ).run((), onValue: (val) => value = val);

      expect(value, 20);
    });

    test('does not execute past first success', () {
      bool thirdCalled = false;

      Cont.any<(), int>(
        [
          Cont.terminate([ContError.capture('err')]),
          Cont.of(20),
          Cont.fromRun((runtime, observer) {
            thirdCalled = true;
            observer.onValue(30);
          }),
        ],
        policy: ContEitherPolicy.sequence(),
      ).run(());

      expect(thirdCalled, false);
    });

    test('collects all errors when all fail', () {
      List<ContError>? errors;

      Cont.any<(), int>(
        [
          Cont.terminate([ContError.capture('err1')]),
          Cont.terminate([ContError.capture('err2')]),
          Cont.terminate([ContError.capture('err3')]),
        ],
        policy: ContEitherPolicy.sequence(),
      ).run((), onTerminate: (e) => errors = e);

      expect(errors!.length, 3);
      expect(errors![0].error, 'err1');
      expect(errors![1].error, 'err2');
      expect(errors![2].error, 'err3');
    });

    test('handles empty list', () {
      List<ContError>? errors;

      Cont.any<(), int>(
        [],
        policy: ContEitherPolicy.sequence(),
      ).run((), onTerminate: (e) => errors = e);

      expect(errors, isNotNull);
      expect(errors, isEmpty);
    });
  });

  group('Cont.any (mergeWhenAll)', () {
    test('combines values when multiple succeed', () {
      int? value;

      Cont.any<(), int>(
        [Cont.of(10), Cont.of(20), Cont.of(30)],
        policy: ContEitherPolicy.mergeWhenAll(
          (a, b) => a + b,
        ),
      ).run((), onValue: (val) => value = val);

      expect(value, 60);
    });

    test('returns single success when others fail', () {
      int? value;

      Cont.any<(), int>(
        [
          Cont.terminate([ContError.capture('err1')]),
          Cont.of(20),
          Cont.terminate([ContError.capture('err3')]),
        ],
        policy: ContEitherPolicy.mergeWhenAll(
          (a, b) => a + b,
        ),
      ).run((), onValue: (val) => value = val);

      expect(value, 20);
    });

    test('collects all errors when all fail', () {
      List<ContError>? errors;

      Cont.any<(), int>(
        [
          Cont.terminate([ContError.capture('err1')]),
          Cont.terminate([ContError.capture('err2')]),
        ],
        policy: ContEitherPolicy.mergeWhenAll(
          (a, b) => a + b,
        ),
      ).run((), onTerminate: (e) => errors = e);

      expect(errors!.length, 2);
      expect(errors![0].error, 'err1');
      expect(errors![1].error, 'err2');
    });
  });

  group('Cont.any (quitFast)', () {
    test('returns first success', () {
      int? value;

      Cont.any<(), int>(
        [Cont.of(10), Cont.of(20)],
        policy: ContEitherPolicy.quitFast(),
      ).run((), onValue: (val) => value = val);

      expect(value, 10);
    });

    test('terminates when all fail', () {
      List<ContError>? errors;

      Cont.any<(), int>(
        [
          Cont.terminate([ContError.capture('err1')]),
          Cont.terminate([ContError.capture('err2')]),
        ],
        policy: ContEitherPolicy.quitFast(),
      ).run((), onTerminate: (e) => errors = e);

      expect(errors, isNotNull);
    });
  });

  group('Cont.any shared', () {
    test('supports multiple runs', () {
      var callCount = 0;
      final cont = Cont.any<(), int>(
        [
          Cont.fromRun((runtime, observer) {
            callCount++;
            observer.onValue(callCount);
          }),
        ],
        policy: ContEitherPolicy.sequence(),
      );

      int? value1;
      cont.run((), onValue: (val) => value1 = val);
      expect(value1, 1);
      expect(callCount, 1);

      int? value2;
      cont.run((), onValue: (val) => value2 = val);
      expect(value2, 2);
      expect(callCount, 2);
    });

    test('makes defensive copy of list', () {
      final list = <Cont<(), int>>[
        Cont.of(1),
        Cont.of(2),
      ];
      final cont = Cont.any<(), int>(
        list,
        policy: ContEitherPolicy.sequence(),
      );

      list.add(Cont.of(3));

      int? value;
      cont.run((), onValue: (val) => value = val);

      expect(value, 1);
    });
  });
}
