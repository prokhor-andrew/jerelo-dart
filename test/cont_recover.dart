import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.recover', () {
    test('recovers from termination with value', () {
      int? value;

      Cont.terminate<(), int>([ContError.capture('err')])
          .recover((errors) => 42)
          .run((), onValue: (val) => value = val);

      expect(value, 42);
    });

    test('receives error list', () {
      List<ContError>? receivedErrors;

      Cont.terminate<(), int>([
            ContError.capture('err1'),
            ContError.capture('err2'),
          ])
          .recover((errors) {
            receivedErrors = errors;
            return 0;
          })
          .run(());

      expect(receivedErrors!.length, 2);
      expect(receivedErrors![0].error, 'err1');
      expect(receivedErrors![1].error, 'err2');
    });

    test('never executes on value path', () {
      bool recoverCalled = false;
      int? value;

      Cont.of<(), int>(42)
          .recover((errors) {
            recoverCalled = true;
            return 0;
          })
          .run((), onValue: (val) => value = val);

      expect(recoverCalled, false);
      expect(value, 42);
    });

    test('terminates when recover function throws', () {
      final cont =
          Cont.terminate<(), int>().recover((errors) {
            throw 'Recover Error';
          });

      ContError? error;
      cont.run(
        (),
        onTerminate: (errors) => error = errors.first,
      );

      expect(error!.error, 'Recover Error');
    });

    test('supports multiple runs', () {
      var callCount = 0;
      final cont = Cont.terminate<(), int>().recover((
        errors,
      ) {
        callCount++;
        return 99;
      });

      int? value1;
      cont.run((), onValue: (val) => value1 = val);
      expect(value1, 99);
      expect(callCount, 1);

      int? value2;
      cont.run((), onValue: (val) => value2 = val);
      expect(value2, 99);
      expect(callCount, 2);
    });

    test('supports empty error list', () {
      List<ContError>? receivedErrors;

      Cont.terminate<(), int>([])
          .recover((errors) {
            receivedErrors = errors;
            return 0;
          })
          .run(());

      expect(receivedErrors, isEmpty);
    });
  });

  group('Cont.recover0', () {
    test('recovers without using errors', () {
      int? value;

      Cont.terminate<(), int>([ContError.capture('err')])
          .recover0(() => 42)
          .run((), onValue: (val) => value = val);

      expect(value, 42);
    });

    test('behaves like recover with ignored errors', () {
      int? value1;
      int? value2;

      final cont1 = Cont.terminate<(), int>().recover0(
        () => 99,
      );
      final cont2 = Cont.terminate<(), int>().recover(
        (_) => 99,
      );

      cont1.run((), onValue: (val) => value1 = val);
      cont2.run((), onValue: (val) => value2 = val);

      expect(value1, value2);
    });
  });

  group('Cont.fallback', () {
    test('provides fallback value on termination', () {
      int? value;

      Cont.terminate<(), int>([ContError.capture('err')])
          .fallback(42)
          .run((), onValue: (val) => value = val);

      expect(value, 42);
    });

    test('never uses fallback on value path', () {
      int? value;

      Cont.of<(), int>(10)
          .fallback(42)
          .run((), onValue: (val) => value = val);

      expect(value, 10);
    });

    test('behaves like recover0 with constant', () {
      int? value1;
      int? value2;

      final cont1 = Cont.terminate<(), int>().fallback(99);
      final cont2 = Cont.terminate<(), int>().recover0(
        () => 99,
      );

      cont1.run((), onValue: (val) => value1 = val);
      cont2.run((), onValue: (val) => value2 = val);

      expect(value1, value2);
    });

    test('supports multiple runs', () {
      final cont = Cont.terminate<(), int>().fallback(42);

      int? value1;
      cont.run((), onValue: (val) => value1 = val);
      expect(value1, 42);

      int? value2;
      cont.run((), onValue: (val) => value2 = val);
      expect(value2, 42);
    });
  });
}
