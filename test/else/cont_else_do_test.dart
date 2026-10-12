import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.elseDo', () {
    test('recovers from termination', () {
      int? value;

      Cont.stop<(), int>()
          .elseDo((errors) => Cont.of(42))
          .run((), onThen: (val) => value = val);

      expect(value, 42);
    });

    test('receives original errors', () {
      List<ContError>? receivedErrors;

      Cont.stop<(), int>([
            ContError.capture('err1'),
            ContError.capture('err2'),
          ])
          .elseDo((errors) {
            receivedErrors = errors;
            return Cont.of(0);
          })
          .run(());

      expect(receivedErrors!.length, 2);
      expect(receivedErrors![0].error, 'err1');
      expect(receivedErrors![1].error, 'err2');
    });

    test(
      'propagates only fallback errors when both fail',
      () {
        List<ContError>? errors;

        Cont.stop<(), int>([ContError.capture('original')])
            .elseDo((e) {
              return Cont.stop<(), int>([
                ContError.capture('fallback'),
              ]);
            })
            .run((), onElse: (e) => errors = e);

        expect(errors!.length, 1);
        expect(errors![0].error, 'fallback');
      },
    );

    test('never executes on value path', () {
      bool elseCalled = false;
      int? value;

      Cont.of<(), int>(42)
          .elseDo((errors) {
            elseCalled = true;
            return Cont.of(0);
          })
          .run((), onThen: (val) => value = val);

      expect(elseCalled, false);
      expect(value, 42);
    });

    test('terminates when fallback builder throws', () {
      final cont = Cont.stop<(), int>().elseDo((errors) {
        throw 'Fallback Builder Error';
      });

      ContError? error;
      cont.run(
        (),
        onElse: (errors) => error = errors.first,
      );

      expect(error!.error, 'Fallback Builder Error');
    });

    test('supports chaining', () {
      int? value;

      Cont.stop<(), int>([ContError.capture('err1')])
          .elseDo(
            (e) => Cont.stop<(), int>([
              ContError.capture('err2'),
            ]),
          )
          .elseDo((e) => Cont.of(42))
          .run((), onThen: (val) => value = val);

      expect(value, 42);
    });

    test('supports multiple runs', () {
      var callCount = 0;
      final cont = Cont.stop<(), int>().elseDo((errors) {
        callCount++;
        return Cont.of(10);
      });

      int? value1;
      cont.run((), onThen: (val) => value1 = val);
      expect(value1, 10);
      expect(callCount, 1);

      int? value2;
      cont.run((), onThen: (val) => value2 = val);
      expect(value2, 10);
      expect(callCount, 2);
    });

    test('supports empty error list', () {
      List<ContError>? receivedErrors;

      Cont.stop<(), int>([])
          .elseDo((errors) {
            receivedErrors = errors;
            return Cont.of(0);
          })
          .run(());

      expect(receivedErrors, isEmpty);
    });

    test('never calls onPanic on value path', () {
      Cont.of<(), int>(42)
          .elseDo((errors) => Cont.of(0))
          .run(
            (),
            onPanic: (_) => fail('Should not be called'),
            onThen: (_) {},
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
              observer.onElse([ContError.capture('error')]);
            });
          }).elseDo((errors) {
            fallbackCalled = true;
            return Cont.of(42);
          });

      int? value;
      final token = cont.run(
        (),
        onThen: (val) => value = val,
      );

      token.cancel();
      flush();

      expect(fallbackCalled, false);
      expect(value, null);
    });

    test('provides defensive copy of errors', () {
      final originalErrors = [ContError.capture('err1')];
      List<ContError>? receivedErrors;

      Cont.stop<(), int>(originalErrors)
          .elseDo((errors) {
            receivedErrors = errors;
            errors.add(ContError.capture('err2'));
            return Cont.of(0);
          })
          .run(());

      expect(originalErrors.length, 1);
      expect(receivedErrors!.length, 2);
    });
  });

  group('Cont.elseDo0', () {
    test('recovers without error information', () {
      int? value;

      Cont.stop<(), int>()
          .elseDo0(() => Cont.of(42))
          .run((), onThen: (val) => value = val);

      expect(value, 42);
    });

    test('behaves like elseDo with ignored errors', () {
      int? value1;
      int? value2;

      final cont1 = Cont.stop<(), int>().elseDo0(
        () => Cont.of(99),
      );
      final cont2 = Cont.stop<(), int>().elseDo(
        (_) => Cont.of(99),
      );

      cont1.run((), onThen: (val) => value1 = val);
      cont2.run((), onThen: (val) => value2 = val);

      expect(value1, value2);
    });
  });
}
