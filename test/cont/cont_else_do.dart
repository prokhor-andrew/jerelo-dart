import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.elseDo', () {
    test('recovers from termination', () {
      int? value;
      Cont.terminate<(), int>()
          .elseDo((errors) => Cont.of(42))
          .run((), onValue: (val) => value = val);

      expect(value, 42);
    });

    test('receives error information', () {
      List<ContError>? receivedErrors;
      Cont.terminate<(), int>([
            ContError('err1', StackTrace.current),
            ContError('err2', StackTrace.current),
          ])
          .elseDo((errors) {
            receivedErrors = errors;
            return Cont.of(99);
          })
          .run(());

      expect(receivedErrors!.length, 2);
      expect(receivedErrors![0].error, 'err1');
      expect(receivedErrors![1].error, 'err2');
    });

    test('never executes on value path', () {
      bool elseCalled = false;
      int? value;

      Cont.of<(), int>(42)
          .elseDo((errors) {
            elseCalled = true;
            return Cont.of(0);
          })
          .run((), onValue: (val) => value = val);

      expect(elseCalled, false);
      expect(value, 42);
    });

    test('replaces errors when fallback succeeds', () {
      int? value;
      List<ContError>? errors;

      Cont.terminate<(), int>([
            ContError('original', StackTrace.current),
          ])
          .elseDo((e) => Cont.of(100))
          .run(
            (),
            onValue: (val) => value = val,
            onTerminate: (e) => errors = e,
          );

      expect(value, 100);
      expect(errors, null);
    });

    test('propagates fallback errors only', () {
      List<ContError>? errors;

      Cont.terminate<(), int>([
            ContError('original', StackTrace.current),
          ])
          .elseDo((e) {
            return Cont.terminate<(), int>([
              ContError('fallback', StackTrace.current),
            ]);
          })
          .run((), onTerminate: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'fallback');
    });

    test('terminates when fallback builder throws', () {
      final cont = Cont.terminate<(), int>().elseDo((
        errors,
      ) {
        throw 'Fallback Builder Error';
      });

      ContError? error;
      cont.run(
        (),
        onTerminate: (errors) => error = errors.first,
      );

      expect(error!.error, 'Fallback Builder Error');
    });

    test('supports chaining', () {
      int? value;

      Cont.terminate<(), int>([
            ContError('err1', StackTrace.current),
          ])
          .elseDo(
            (e) => Cont.terminate<(), int>([
              ContError('err2', StackTrace.current),
            ]),
          )
          .elseDo((e) => Cont.of(42))
          .run((), onValue: (val) => value = val);

      expect(value, 42);
    });

    test('supports multiple runs', () {
      var callCount = 0;
      final cont = Cont.terminate<(), int>().elseDo((
        errors,
      ) {
        callCount++;
        return Cont.of(10);
      });

      int? value1;
      cont.run((), onValue: (val) => value1 = val);
      expect(value1, 10);
      expect(callCount, 1);

      int? value2;
      cont.run((), onValue: (val) => value2 = val);
      expect(value2, 10);
      expect(callCount, 2);
    });

    test('supports empty error list', () {
      List<ContError>? receivedErrors;
      int? value;

      Cont.terminate<(), int>([])
          .elseDo((errors) {
            receivedErrors = errors;
            return Cont.of(50);
          })
          .run((), onValue: (val) => value = val);

      expect(receivedErrors, isEmpty);
      expect(value, 50);
    });

    test('never calls onPanic on value path', () {
      Cont.of<(), int>(42)
          .elseDo((errors) => Cont.of(0))
          .run(
            (),
            onPanic: (_) => fail('Should not be called'),
            onValue: (_) {},
          );
    });

    test('prevents fallback after cancellation', () {
      bool fallbackCalled = false;

      final List<void Function()> buffer = [];
      void flush() {
        for (final fn in buffer) {
          fn();
        }
        buffer.clear();
      }

      final cont =
          Cont.fromRun<(), int>((runtime, observer) {
            buffer.add(() {
              if (runtime.isCancelled()) return;
              observer.onTerminate([
                ContError('error', StackTrace.current),
              ]);
            });
          }).elseDo((errors) {
            fallbackCalled = true;
            return Cont.of(42);
          });

      int? value;
      final token = cont.run(
        (),
        onValue: (val) => value = val,
      );

      token.cancel();
      flush();

      expect(fallbackCalled, false);
      expect(value, null);
    });

    test('provides defensive copy of errors', () {
      final originalErrors = [
        ContError('err1', StackTrace.current),
      ];
      List<ContError>? receivedErrors;

      Cont.terminate<(), int>(originalErrors)
          .elseDo((errors) {
            receivedErrors = errors;
            errors.add(
              ContError('err2', StackTrace.current),
            );
            return Cont.of(0);
          })
          .run(());

      expect(originalErrors.length, 1);
      expect(receivedErrors!.length, 2);
    });

    test('elseDo0 ignores error list', () {
      int? value1;
      int? value2;

      final cont1 = Cont.terminate<(), int>().elseDo0(
        () => Cont.of(42),
      );
      final cont2 = Cont.terminate<(), int>().elseDo(
        (_) => Cont.of(42),
      );

      cont1.run((), onValue: (val) => value1 = val);
      cont2.run((), onValue: (val) => value2 = val);

      expect(value1, value2);
      expect(value1, 42);
    });

    test('transforms error type to value', () {
      String? value;

      Cont.terminate<(), String>([
            ContError('error message', StackTrace.current),
          ])
          .elseDo((errors) {
            return Cont.of(
              'Recovered from: ${errors.first.error}',
            );
          })
          .run((), onValue: (val) => value = val);

      expect(value, 'Recovered from: error message');
    });

    test('works in thenDo chain', () {
      int? value;

      Cont.of<(), int>(10)
          .thenDo(
            (a) => Cont.terminate<(), int>([
              ContError('error', StackTrace.current),
            ]),
          )
          .elseDo((errors) => Cont.of(99))
          .run((), onValue: (val) => value = val);

      expect(value, 99);
    });
  });
}
