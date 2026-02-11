import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.thenDo', () {
    test('Cont.thenDo runs on value channel', () {
      int? value;
      Cont.of<(), int>(0)
          .thenDo((a) => Cont.of(a + 2))
          .run((), onThen: (val) => value = val);

      expect(value, 2);
    });

    test('Cont.thenDo monad right identity law', () {
      int? value1;
      int? value2;

      final f = (int a) => Cont.of<(), int>(a * 2);
      final cont1 = f(5);
      final cont2 = Cont.of<(), int>(5).thenDo(f);

      cont1.run((), onThen: (val) => value1 = val);
      cont2.run((), onThen: (val) => value2 = val);

      expect(value1, value2);
    });

    test('Cont.thenDo monad left identity law', () {
      int? value1;
      int? value2;

      final cont1 = Cont.of<(), int>(5);
      final cont2 = cont1.thenDo(Cont.of);

      cont1.run((), onThen: (val1) => value1 = val1);
      cont2.run((), onThen: (val2) => value2 = val2);

      expect(value1, value2);
    });

    test('Cont.thenDo monad associativity law', () {
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

      cont2.run((), onThen: (val2) => value2 = val2);
      cont3.run((), onThen: (val3) => value3 = val3);

      expect(value2, value3);
    });

    test('Cont.thenDo ignore terminate channel', () {
      final cont = Cont.stop<(), int>().thenDo(
        (a) => Cont.of(a * 2),
      );

      cont.run(
        (),
        onThen: (_) => fail('Must not be called'),
      );
    });

    test('Cont.thenDo throw terminates', () {
      final cont = Cont.of<(), int>(0).thenDo((val) {
        throw 'Thrown Error';
      });

      ContError? error;
      cont.run(
        (),
        onElse: (errors) => error = errors.first,
      );

      expect(error!.error, 'Thrown Error');
    });

    test('Cont.thenDo transforms types', () {
      String? value;

      Cont.of<(), int>(42)
          .thenDo((val) => Cont.of('value: $val'))
          .run((), onThen: (val) => value = val);

      expect(value, 'value: 42');
    });

    test(
      'Cont.thenDo calls onElse when terminated',
      () {
        List<ContError>? errors;

        Cont.stop<(), int>()
            .thenDo((a) => Cont.of(a * 2))
            .run((), onElse: (e) => errors = e);

        expect(errors, isNotNull);
        expect(errors, isEmpty);
      },
    );

    test(
      'Cont.thenDo passes through termination errors',
      () {
        final inputErrors = [
          ContError.capture('err1'),
          ContError.capture('err2'),
        ];

        List<ContError>? receivedErrors;

        Cont.stop<(), int>(inputErrors)
            .thenDo((val) => Cont.of(val + 5))
            .run(
              (),
              onElse: (e) => receivedErrors = e,
            );

        expect(receivedErrors!.length, 2);
        expect(receivedErrors![0].error, 'err1');
        expect(receivedErrors![1].error, 'err2');
      },
    );

    test(
      'Cont.thenDo terminates when returned continuation terminates',
      () {
        final cont = Cont.of<(), int>(
          5,
        ).thenDo((a) => Cont.stop<(), int>());

        cont.run(
          (),
          onThen: (_) =>
              fail('onThen must not be called'),
          onElse: (_) {}, // Should be called
        );
      },
    );

    test('Cont.thenDo can be run multiple times', () {
      final cont = Cont.of<(), int>(
        10,
      ).thenDo((val) => Cont.of(val * 3));

      int? value1;
      cont.run((), onThen: (val) => value1 = val);
      expect(value1, 30);

      int? value2;
      cont.run((), onThen: (val) => value2 = val);
      expect(value2, 30);
    });

    test('Cont.thenDo does not call onPanic', () {
      Cont.of<(), int>(0)
          .thenDo((val) => Cont.of(val + 5))
          .run(
            (),
            onPanic: (_) => fail('Should not be called'),
            onThen: (_) {},
          );
    });

    test(
      'Cont.thenDo cancellation prevents thenDo execution',
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
                observer.onThen(10);
              });
            }).thenDo((val) {
              thenDoCalled = true;
              return Cont.of(val + 5);
            });

        int? value;
        final token = cont.run(
          (),
          onThen: (val) => value = val,
        );

        token.cancel();
        flush();

        expect(thenDoCalled, false);
        expect(value, null);
      },
    );

    test('Cont.thenDo0 is thenDo with ignored input', () {
      final cont1 = Cont.of<(), int>(
        0,
      ).thenDo0(() => Cont.of(5));
      final cont2 = Cont.of<(), int>(
        0,
      ).thenDo((_) => Cont.of(5));

      int? value1;
      int? value2;

      cont1.run((), onThen: (val1) => value1 = val1);
      cont2.run((), onThen: (val2) => value2 = val2);

      expect(value1, value2);
    });
  });
}
