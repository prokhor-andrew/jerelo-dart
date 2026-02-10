import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.thenDo', () {
    test('executes on value channel', () {
      int? value;
      Cont.of<(), int>(0)
          .thenDo((a) => Cont.of(a + 2))
          .run((), onValue: (val) => value = val);

      expect(value, 2);
    });

    test('preserves monad right identity law', () {
      int? value1;
      int? value2;

      final f = (int a) => Cont.of<(), int>(a * 2);
      final cont1 = f(5);
      final cont2 = Cont.of<(), int>(5).thenDo(f);

      cont1.run((), onValue: (val) => value1 = val);
      cont2.run((), onValue: (val) => value2 = val);

      expect(value1, value2);
    });

    test('preserves monad left identity law', () {
      int? value1;
      int? value2;

      final cont1 = Cont.of<(), int>(5);
      final cont2 = cont1.thenDo(Cont.of);

      cont1.run((), onValue: (val1) => value1 = val1);
      cont2.run((), onValue: (val2) => value2 = val2);

      expect(value1, value2);
    });

    test('preserves monad associativity law', () {
      int? value2;
      int? value3;

      final cont1 = Cont.of<(), int>(5);
      final cont2 = cont1
          .thenDo((a) => Cont.of(a * 2))
          .thenDo((a) => Cont.of(a * 3));
      final cont3 = cont1.thenDo(
        (a) => Cont.of<(), int>(
          a * 2,
        ).thenDo((a) => Cont.of(a * 3)),
      );

      cont2.run((), onValue: (val2) => value2 = val2);
      cont3.run((), onValue: (val3) => value3 = val3);

      expect(value2, value3);
    });

    test('never executes on termination', () {
      final cont = Cont.terminate<(), int>().thenDo(
        (a) => Cont.of(a * 2),
      );

      cont.run(
        (),
        onValue: (_) => fail('Must not be called'),
      );
    });

    test('terminates when function throws', () {
      final cont = Cont.of<(), int>(0).thenDo((val) {
        throw 'Thrown Error';
      });

      ContError? error;
      cont.run(
        (),
        onTerminate: (errors) => error = errors.first,
      );

      expect(error!.error, 'Thrown Error');
    });

    test('transforms value types', () {
      String? value;

      Cont.of<(), int>(42)
          .thenDo((val) => Cont.of('value: $val'))
          .run((), onValue: (val) => value = val);

      expect(value, 'value: 42');
    });

    test('delivers termination when source terminates', () {
      List<ContError>? errors;

      Cont.terminate<(), int>()
          .thenDo((a) => Cont.of(a * 2))
          .run((), onTerminate: (e) => errors = e);

      expect(errors, isNotNull);
      expect(errors, isEmpty);
    });

    test('passes through termination errors', () {
      final inputErrors = [
        ContError('err1', StackTrace.current),
        ContError('err2', StackTrace.current),
      ];

      List<ContError>? receivedErrors;

      Cont.terminate<(), int>(inputErrors)
          .thenDo((val) => Cont.of(val + 5))
          .run((), onTerminate: (e) => receivedErrors = e);

      expect(receivedErrors!.length, 2);
      expect(receivedErrors![0].error, 'err1');
      expect(receivedErrors![1].error, 'err2');
    });

    test(
      'terminates when returned continuation terminates',
      () {
        final cont = Cont.of<(), int>(
          5,
        ).thenDo((a) => Cont.terminate<(), int>());

        cont.run(
          (),
          onValue: (_) =>
              fail('onValue must not be called'),
          onTerminate: (_) {}, // Should be called
        );
      },
    );

    test('supports multiple runs', () {
      final cont = Cont.of<(), int>(
        10,
      ).thenDo((val) => Cont.of(val * 3));

      int? value1;
      cont.run((), onValue: (val) => value1 = val);
      expect(value1, 30);

      int? value2;
      cont.run((), onValue: (val) => value2 = val);
      expect(value2, 30);
    });

    test('supports null values', () {
      String? value = 'initial';

      Cont.of<(), String?>(null)
          .thenDo((val) => Cont.of(val))
          .run((), onValue: (val) => value = val);

      expect(value, null);
    });

    test('never calls onPanic', () {
      Cont.of<(), int>(0)
          .thenDo((val) => Cont.of(val + 5))
          .run(
            (),
            onPanic: (_) => fail('Should not be called'),
            onValue: (_) {},
          );
    });

    test(
      'prevents thenDo execution after cancellation',
      () {
        bool thenDoCalled = false;

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
                observer.onValue(10);
              });
            }).thenDo((val) {
              thenDoCalled = true;
              return Cont.of(val + 5);
            });

        int? value;
        final token = cont.run(
          (),
          onValue: (val) => value = val,
        );

        token.cancel();
        flush();

        expect(thenDoCalled, false);
        expect(value, null);
      },
    );

    test('supports chaining multiple operations', () {
      String? value;

      Cont.of<(), int>(10)
          .thenDo((a) => Cont.of(a + 5))
          .thenDo((b) => Cont.of(b * 2))
          .thenDo((c) => Cont.of('Result: $c'))
          .run((), onValue: (val) => value = val);

      expect(value, 'Result: 30');
    });

    test('thenDo0 ignores input value', () {
      final cont1 = Cont.of<(), int>(
        0,
      ).thenDo0(() => Cont.of(5));
      final cont2 = Cont.of<(), int>(
        0,
      ).thenDo((_) => Cont.of(5));

      int? value1;
      int? value2;

      cont1.run((), onValue: (val1) => value1 = val1);
      cont2.run((), onValue: (val2) => value2 = val2);

      expect(value1, value2);
    });
  });
}
