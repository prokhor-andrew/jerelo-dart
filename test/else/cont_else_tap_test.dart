import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.elseTap', () {
    test('executes side effect on termination', () {
      var sideEffectErrors = <ContError>[];
      List<ContError>? errors;

      Cont.stop<(), int>([ContError.capture('err1')])
          .elseTap((e) {
            sideEffectErrors = e;
            return Cont.stop<(), int>([]);
          })
          .run((), onElse: (e) => errors = e);

      expect(sideEffectErrors.length, 1);
      expect(sideEffectErrors[0].error, 'err1');
      expect(errors!.length, 1);
      expect(errors![0].error, 'err1');
    });

    test(
      'propagates original errors when side effect succeeds',
      () {
        List<ContError>? errors;

        Cont.stop<(), int>([ContError.capture('original')])
            .elseTap((e) => Cont.stop<(), int>([]))
            .run((), onElse: (e) => errors = e);

        expect(errors!.length, 1);
        expect(errors![0].error, 'original');
      },
    );

    test('recovers when side effect succeeds', () {
      int? value;

      Cont.stop<(), int>([ContError.capture('original')])
          .elseTap((e) => Cont.of(42))
          .run((), onThen: (val) => value = val);

      expect(value, 42);
    });

    test('propagates side effect termination', () {
      List<ContError>? errors;

      Cont.stop<(), int>([ContError.capture('original')])
          .elseTap((e) {
            return Cont.stop<(), int>([
              ContError.capture('side effect'),
            ]);
          })
          .run((), onElse: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'original');
    });

    test('never executes on value path', () {
      bool elseCalled = false;
      int? value;

      Cont.of<(), int>(42)
          .elseTap((errors) {
            elseCalled = true;
            return Cont.stop<(), int>([]);
          })
          .run((), onThen: (val) => value = val);

      expect(elseCalled, false);
      expect(value, 42);
    });

    test('terminates when side effect builder throws', () {
      final cont =
          Cont.stop<(), int>([
            ContError.capture('original'),
          ]).elseTap((errors) {
            throw 'Side Effect Builder Error';
          });

      ContError? error;
      cont.run(
        (),
        onElse: (errors) => error = errors.first,
      );

      expect(error!.error, 'original');
    });

    test('supports multiple runs', () {
      var callCount = 0;
      final cont = Cont.stop<(), int>().elseTap((errors) {
        callCount++;
        return Cont.stop<(), int>([]);
      });

      cont.run((), onElse: (_) {});
      expect(callCount, 1);

      cont.run((), onElse: (_) {});
      expect(callCount, 2);
    });

    test('supports empty error list', () {
      List<ContError>? receivedErrors;

      Cont.stop<(), int>([])
          .elseTap((errors) {
            receivedErrors = errors;
            return Cont.stop<(), int>([]);
          })
          .run((), onElse: (_) {});

      expect(receivedErrors, isEmpty);
    });

    test('never calls onPanic on value path', () {
      Cont.of<(), int>(42)
          .elseTap((errors) => Cont.stop<(), int>([]))
          .run(
            (),
            onPanic: (_) => fail('Should not be called'),
            onThen: (_) {},
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
              observer.onElse([ContError.capture('error')]);
            });
          }).elseTap((errors) {
            sideEffectCalled = true;
            return Cont.stop<(), int>([]);
          });

      final token = cont.run((), onElse: (_) {});

      token.cancel();
      flush();

      expect(sideEffectCalled, false);
    });

    test('provides defensive copy of errors', () {
      final originalErrors = [ContError.capture('err1')];
      List<ContError>? receivedErrors;

      Cont.stop<(), int>(originalErrors)
          .elseTap((errors) {
            receivedErrors = errors;
            errors.add(ContError.capture('err2'));
            return Cont.stop<(), int>([]);
          })
          .run((), onElse: (_) {});

      expect(originalErrors.length, 1);
      expect(receivedErrors!.length, 2);
    });

    test('elseTap0 ignores error list', () {
      var count1 = 0;
      var count2 = 0;

      final cont1 = Cont.stop<(), int>().elseTap0(() {
        count1++;
        return Cont.stop<(), int>([]);
      });
      final cont2 = Cont.stop<(), int>().elseTap((_) {
        count2++;
        return Cont.stop<(), int>([]);
      });

      cont1.run((), onElse: (_) {});
      cont2.run((), onElse: (_) {});

      expect(count1, 1);
      expect(count2, 1);
    });

    test('recovers with value-returning side effect', () {
      int? value;

      Cont.stop<(), int>([ContError.capture('error')])
          .elseTap((errors) => Cont.of(100))
          .run((), onThen: (val) => value = val);

      expect(value, 100);
    });
  });
}
