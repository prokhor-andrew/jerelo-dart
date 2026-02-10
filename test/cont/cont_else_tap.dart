import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.elseTap', () {
    test('executes side effect on termination', () {
      var sideEffectErrors = <ContError>[];
      List<ContError>? errors;

      Cont.terminate<(), int>([ContError.capture('err1')])
          .elseTap((e) {
            sideEffectErrors = e;
            return Cont.terminate<(), int>([]);
          })
          .run((), onTerminate: (e) => errors = e);

      expect(sideEffectErrors.length, 1);
      expect(sideEffectErrors[0].error, 'err1');
      expect(errors!.length, 1);
      expect(errors![0].error, 'err1');
    });

    test(
      'propagates original errors when side effect succeeds',
      () {
        List<ContError>? errors;

        Cont.terminate<(), int>([
              ContError.capture('original'),
            ])
            .elseTap((e) => Cont.terminate<(), int>([]))
            .run((), onTerminate: (e) => errors = e);

        expect(errors!.length, 1);
        expect(errors![0].error, 'original');
      },
    );

    test('recovers when side effect succeeds', () {
      int? value;

      Cont.terminate<(), int>([
            ContError.capture('original'),
          ])
          .elseTap((e) => Cont.of(42))
          .run((), onValue: (val) => value = val);

      expect(value, 42);
    });

    test('propagates side effect termination', () {
      List<ContError>? errors;

      Cont.terminate<(), int>([
            ContError.capture('original'),
          ])
          .elseTap((e) {
            return Cont.terminate<(), int>([
              ContError.capture('side effect'),
            ]);
          })
          .run((), onTerminate: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'original');
    });

    test('never executes on value path', () {
      bool elseCalled = false;
      int? value;

      Cont.of<(), int>(42)
          .elseTap((errors) {
            elseCalled = true;
            return Cont.terminate<(), int>([]);
          })
          .run((), onValue: (val) => value = val);

      expect(elseCalled, false);
      expect(value, 42);
    });

    test('terminates when side effect builder throws', () {
      final cont =
          Cont.terminate<(), int>([
            ContError.capture('original'),
          ]).elseTap((errors) {
            throw 'Side Effect Builder Error';
          });

      ContError? error;
      cont.run(
        (),
        onTerminate: (errors) => error = errors.first,
      );

      expect(error!.error, 'original');
    });

    test('supports chaining', () {
      final effects = <String>[];
      List<ContError>? errors;

      Cont.terminate<(), int>([ContError.capture('err1')])
          .elseTap((e) {
            effects.add('first');
            return Cont.terminate<(), int>([]);
          })
          .elseTap((e) {
            effects.add('second');
            return Cont.terminate<(), int>([]);
          })
          .run((), onTerminate: (e) => errors = e);

      expect(effects, ['first', 'second']);
      expect(errors!.length, 1);
    });

    test('supports multiple runs', () {
      var callCount = 0;
      final cont = Cont.terminate<(), int>().elseTap((
        errors,
      ) {
        callCount++;
        return Cont.terminate<(), int>([]);
      });

      cont.run((), onTerminate: (_) {});
      expect(callCount, 1);

      cont.run((), onTerminate: (_) {});
      expect(callCount, 2);
    });

    test('supports empty error list', () {
      List<ContError>? receivedErrors;

      Cont.terminate<(), int>([])
          .elseTap((errors) {
            receivedErrors = errors;
            return Cont.terminate<(), int>([]);
          })
          .run((), onTerminate: (_) {});

      expect(receivedErrors, isEmpty);
    });

    test('never calls onPanic on value path', () {
      Cont.of<(), int>(42)
          .elseTap((errors) => Cont.terminate<(), int>([]))
          .run(
            (),
            onPanic: (_) => fail('Should not be called'),
            onValue: (_) {},
          );
    });

    test('prevents side effect after cancellation', () {
      bool sideEffectCalled = false;

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
                ContError.capture('error'),
              ]);
            });
          }).elseTap((errors) {
            sideEffectCalled = true;
            return Cont.terminate<(), int>([]);
          });

      final token = cont.run((), onTerminate: (_) {});

      token.cancel();
      flush();

      expect(sideEffectCalled, false);
    });

    test('provides defensive copy of errors', () {
      final originalErrors = [ContError.capture('err1')];
      List<ContError>? receivedErrors;

      Cont.terminate<(), int>(originalErrors)
          .elseTap((errors) {
            receivedErrors = errors;
            errors.add(ContError.capture('err2'));
            return Cont.terminate<(), int>([]);
          })
          .run((), onTerminate: (_) {});

      expect(originalErrors.length, 1);
      expect(receivedErrors!.length, 2);
    });

    test('elseTap0 ignores error list', () {
      var count1 = 0;
      var count2 = 0;

      final cont1 = Cont.terminate<(), int>().elseTap0(() {
        count1++;
        return Cont.terminate<(), int>([]);
      });
      final cont2 = Cont.terminate<(), int>().elseTap((_) {
        count2++;
        return Cont.terminate<(), int>([]);
      });

      cont1.run((), onTerminate: (_) {});
      cont2.run((), onTerminate: (_) {});

      expect(count1, 1);
      expect(count2, 1);
    });

    test('recovers with value-returning side effect', () {
      int? value;

      Cont.terminate<(), int>([ContError.capture('error')])
          .elseTap((errors) => Cont.of(100))
          .run((), onValue: (val) => value = val);

      expect(value, 100);
    });

    test('works in thenDo chain', () {
      var sideEffectCalled = false;
      List<ContError>? errors;

      Cont.of<(), int>(10)
          .thenDo(
            (a) => Cont.terminate<(), int>([
              ContError.capture('error'),
            ]),
          )
          .elseTap((e) {
            sideEffectCalled = true;
            return Cont.terminate<(), int>([]);
          })
          .run((), onTerminate: (e) => errors = e);

      expect(sideEffectCalled, true);
      expect(errors!.length, 1);
    });
  });
}
