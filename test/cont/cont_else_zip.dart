import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.elseZip', () {
    test('recovers from termination', () {
      int? value;
      Cont.terminate<(), int>()
          .elseZip((errors) => Cont.of(42))
          .run((), onValue: (val) => value = val);

      expect(value, 42);
    });

    test('combines errors when both fail', () {
      List<ContError>? errors;

      Cont.terminate<(), int>([
            ContError('err1', StackTrace.current),
          ])
          .elseZip((e) {
            return Cont.terminate<(), int>([
              ContError('err2', StackTrace.current),
            ]);
          })
          .run((), onTerminate: (e) => errors = e);

      expect(errors!.length, 2);
      expect(errors![0].error, 'err1');
      expect(errors![1].error, 'err2');
    });

    test('receives original error information', () {
      List<ContError>? receivedErrors;
      Cont.terminate<(), int>([
            ContError('original', StackTrace.current),
          ])
          .elseZip((errors) {
            receivedErrors = errors;
            return Cont.of(99);
          })
          .run(());

      expect(receivedErrors!.length, 1);
      expect(receivedErrors![0].error, 'original');
    });

    test('never executes on value path', () {
      bool elseCalled = false;
      int? value;

      Cont.of<(), int>(42)
          .elseZip((errors) {
            elseCalled = true;
            return Cont.of(0);
          })
          .run((), onValue: (val) => value = val);

      expect(elseCalled, false);
      expect(value, 42);
    });

    test('succeeds with fallback value', () {
      int? value;
      List<ContError>? errors;

      Cont.terminate<(), int>([
            ContError('original', StackTrace.current),
          ])
          .elseZip((e) => Cont.of(100))
          .run(
            (),
            onValue: (val) => value = val,
            onTerminate: (e) => errors = e,
          );

      expect(value, 100);
      expect(errors, null);
    });

    test('accumulates multiple failures', () {
      List<ContError>? errors;

      Cont.terminate<(), int>([
            ContError('err1', StackTrace.current),
            ContError('err2', StackTrace.current),
          ])
          .elseZip((e) {
            return Cont.terminate<(), int>([
              ContError('err3', StackTrace.current),
              ContError('err4', StackTrace.current),
            ]);
          })
          .run((), onTerminate: (e) => errors = e);

      expect(errors!.length, 4);
      expect(errors![0].error, 'err1');
      expect(errors![1].error, 'err2');
      expect(errors![2].error, 'err3');
      expect(errors![3].error, 'err4');
    });

    test('terminates when fallback builder throws', () {
      final cont = Cont.terminate<(), int>().elseZip((
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
          .elseZip(
            (e) => Cont.terminate<(), int>([
              ContError('err2', StackTrace.current),
            ]),
          )
          .elseZip((e) => Cont.of(42))
          .run((), onValue: (val) => value = val);

      expect(value, 42);
    });

    test('accumulates errors in chained failures', () {
      List<ContError>? errors;

      Cont.terminate<(), int>([
            ContError('err1', StackTrace.current),
          ])
          .elseZip(
            (e) => Cont.terminate<(), int>([
              ContError('err2', StackTrace.current),
            ]),
          )
          .elseZip(
            (e) => Cont.terminate<(), int>([
              ContError('err3', StackTrace.current),
            ]),
          )
          .run((), onTerminate: (e) => errors = e);

      expect(errors!.length, 3);
      expect(errors![0].error, 'err1');
      expect(errors![1].error, 'err2');
      expect(errors![2].error, 'err3');
    });

    test('supports multiple runs', () {
      var callCount = 0;
      final cont = Cont.terminate<(), int>().elseZip((
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

    test('supports empty error lists', () {
      List<ContError>? errors;

      Cont.terminate<(), int>([])
          .elseZip((e) => Cont.terminate<(), int>([]))
          .run((), onTerminate: (e) => errors = e);

      expect(errors, isEmpty);
    });

    test('never calls onPanic on value path', () {
      Cont.of<(), int>(42)
          .elseZip((errors) => Cont.of(0))
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
          }).elseZip((errors) {
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
          .elseZip((errors) {
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

    test('elseZip0 ignores error list', () {
      List<ContError>? errors1;
      List<ContError>? errors2;

      final cont1 =
          Cont.terminate<(), int>([
            ContError('err1', StackTrace.current),
          ]).elseZip0(
            () => Cont.terminate<(), int>([
              ContError('err2', StackTrace.current),
            ]),
          );

      final cont2 =
          Cont.terminate<(), int>([
            ContError('err1', StackTrace.current),
          ]).elseZip(
            (_) => Cont.terminate<(), int>([
              ContError('err2', StackTrace.current),
            ]),
          );

      cont1.run((), onTerminate: (e) => errors1 = e);
      cont2.run((), onTerminate: (e) => errors2 = e);

      expect(errors1!.length, errors2!.length);
      expect(errors1!.length, 2);
    });

    test('differs from elseDo in error handling', () {
      List<ContError>? elseDoErrors;
      List<ContError>? elseZipErrors;

      final original = [
        ContError('original', StackTrace.current),
      ];
      final fallback = [
        ContError('fallback', StackTrace.current),
      ];

      Cont.terminate<(), int>(original)
          .elseDo((e) => Cont.terminate<(), int>(fallback))
          .run((), onTerminate: (e) => elseDoErrors = e);

      Cont.terminate<(), int>(original)
          .elseZip((e) => Cont.terminate<(), int>(fallback))
          .run((), onTerminate: (e) => elseZipErrors = e);

      expect(
        elseDoErrors!.length,
        1,
      ); // elseDo only keeps fallback errors
      expect(elseDoErrors![0].error, 'fallback');

      expect(
        elseZipErrors!.length,
        2,
      ); // elseZip combines both
      expect(elseZipErrors![0].error, 'original');
      expect(elseZipErrors![1].error, 'fallback');
    });
  });
}
