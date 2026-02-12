import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.recover', () {
    test('recovers from termination with value', () {
      int? value;

      Cont.stop<(), int>([ContError.capture('err')])
          .recover((errors) => 42)
          .run((), onThen: (val) => value = val);

      expect(value, 42);
    });

    test('receives error list', () {
      List<ContError>? receivedErrors;

      Cont.stop<(), int>([
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
          .run((), onThen: (val) => value = val);

      expect(recoverCalled, false);
      expect(value, 42);
    });

    test('terminates when recover function throws', () {
      final cont = Cont.stop<(), int>().recover((errors) {
        throw 'Recover Error';
      });

      ContError? error;
      cont.run(
        (),
        onElse: (errors) => error = errors.first,
      );

      expect(error!.error, 'Recover Error');
    });

    test('supports multiple runs', () {
      var callCount = 0;
      final cont = Cont.stop<(), int>().recover((errors) {
        callCount++;
        return 99;
      });

      int? value1;
      cont.run((), onThen: (val) => value1 = val);
      expect(value1, 99);
      expect(callCount, 1);

      int? value2;
      cont.run((), onThen: (val) => value2 = val);
      expect(value2, 99);
      expect(callCount, 2);
    });

    test('supports empty error list', () {
      List<ContError>? receivedErrors;

      Cont.stop<(), int>([])
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

      Cont.stop<(), int>([ContError.capture('err')])
          .recover0(() => 42)
          .run((), onThen: (val) => value = val);

      expect(value, 42);
    });

    test('behaves like recover with ignored errors', () {
      int? value1;
      int? value2;

      final cont1 = Cont.stop<(), int>().recover0(() => 99);
      final cont2 = Cont.stop<(), int>().recover((_) => 99);

      cont1.run((), onThen: (val) => value1 = val);
      cont2.run((), onThen: (val) => value2 = val);

      expect(value1, value2);
    });
  });

  group('Cont.fallback', () {
    test('provides fallback value on termination', () {
      int? value;

      Cont.stop<(), int>([ContError.capture('err')])
          .recoverWith(42)
          .run((), onThen: (val) => value = val);

      expect(value, 42);
    });

    test('never uses fallback on value path', () {
      int? value;

      Cont.of<(), int>(10)
          .recoverWith(42)
          .run((), onThen: (val) => value = val);

      expect(value, 10);
    });

    test('behaves like recover0 with constant', () {
      int? value1;
      int? value2;

      final cont1 = Cont.stop<(), int>().recoverWith(99);
      final cont2 = Cont.stop<(), int>().recover0(() => 99);

      cont1.run((), onThen: (val) => value1 = val);
      cont2.run((), onThen: (val) => value2 = val);

      expect(value1, value2);
    });

    test('supports multiple runs', () {
      final cont = Cont.stop<(), int>().recoverWith(42);

      int? value1;
      cont.run((), onThen: (val) => value1 = val);
      expect(value1, 42);

      int? value2;
      cont.run((), onThen: (val) => value2 = val);
      expect(value2, 42);
    });
  });
}
