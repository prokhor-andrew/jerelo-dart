import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.thenMap', () {
    test('Cont.thenMap runs on value channel', () {
      final cont = Cont.of<(), int>(
        0,
      ).thenMap((val) => val + 5);

      int? value = null;

      expect(value, null);
      cont.run((), onThen: (val) => value = val);

      expect(value, 5);
    });

    test('Cont.thenMap throw terminates', () {
      final cont = Cont.of<(), int>(0).thenMap((val) {
        throw 'Thrown Error';
      });

      ContError? error = null;

      expect(error, null);
      cont.run(
        (),
        onElse: (errors) => error = errors.first,
      );

      expect(error!.error, 'Thrown Error');
    });

    test('Cont.thenMap functor identity law', () {
      A id<A>(A a) => a;

      final cont1 = Cont.of<(), int>(0);

      final cont2 = cont1.thenMap(id);

      int? value1 = null;
      int? value2 = null;

      expect(value1, null);
      cont1.run((), onThen: (val1) => value1 = val1);

      expect(value2, null);
      cont2.run((), onThen: (val2) => value2 = val2);

      expect(value1, value2);
    });

    test('Cont.thenMap passes through termination', () {
      final errors = [
        ContError.capture('err1'),
        ContError.capture('err2'),
      ];
      final cont = Cont.stop<(), int>(
        errors,
      ).thenMap((val) => val + 5);

      List<ContError>? received;

      cont.run((), onElse: (e) => received = e);

      expect(received!.length, 2);
      expect(received![0].error, 'err1');
      expect(received![1].error, 'err2');
    });

    test(
      'Cont.thenMap does not call onThen on termination',
      () {
        final cont = Cont.stop<(), int>().thenMap(
          (val) => val + 5,
        );

        cont.run(
          (),
          onThen: (_) {
            fail('Should not be called');
          },
        );
      },
    );

    test('Cont.thenMap transforms type', () {
      final cont = Cont.of<(), int>(
        42,
      ).thenMap((val) => 'value: $val');

      String? value;
      cont.run((), onThen: (val) => value = val);

      expect(value, 'value: 42');
    });

    test('Cont.thenMap can be run multiple times', () {
      final cont = Cont.of<(), int>(
        10,
      ).thenMap((val) => val * 3);

      int? value1;
      cont.run((), onThen: (val) => value1 = val);
      expect(value1, 30);

      int? value2;
      cont.run((), onThen: (val) => value2 = val);
      expect(value2, 30);
    });

    test('Cont.thenMap does not call onPanic', () {
      final cont = Cont.of<(), int>(
        0,
      ).thenMap((val) => val + 5);

      cont.run(
        (),
        onPanic: (_) {
          fail('Should not be called');
        },
        onThen: (_) {},
      );
    });

    test(
      'Cont.thenMap cancellation prevents map execution',
      () {
        bool mapCalled = false;

        final List<void Function()> buffer = [];
        void flush() {
          for (final value in buffer) {
            value();
          }
          buffer.clear();
        }

        final cont =
            Cont.fromRun<(), int>((runtime, observer) {
              buffer.add(() {
                if (runtime.isCancelled()) return;
                observer.onThen(10);
              });
            }).thenMap((val) {
              mapCalled = true;
              return val + 5;
            });

        int? value;
        final token = cont.run(
          (),
          onThen: (val) => value = val,
        );

        token.cancel();
        flush();

        expect(mapCalled, false);
        expect(value, null);
      },
    );

    test('Cont.thenMap functor composition law', () {
      C Function(A) compose<A, B, C>(
        B Function(A) lf,
        C Function(B) rf,
      ) {
        return (a) {
          return rf(lf(a));
        };
      }

      int add5(int a) => a + 5;
      int mul2(int a) => a * 2;

      final cont1 = Cont.of<(), int>(10);

      final cont2 = cont1.thenMap(add5).thenMap(mul2);

      final cont3 = cont1.thenMap(compose(add5, mul2));

      int? value2 = null;
      int? value3 = null;

      expect(value2, null);
      cont2.run((), onThen: (val2) => value2 = val2);
      expect(value3, null);
      cont3.run((), onThen: (val3) => value3 = val3);

      expect(value2, value3);
    });

    test(
      'Cont.thenMap0 is thenMap with ignored argument',
      () {
        final cont1 = Cont.of<(), int>(
          10,
        ).thenMap0(() => 20);

        final cont2 = Cont.of<(), int>(
          10,
        ).thenMap((_) => 20);

        int? value1;
        int? value2;
        cont1.run((), onThen: (val) => value1 = val);
        cont2.run((), onThen: (val) => value2 = val);

        expect(value1, 20);
        expect(value2, 20);
      },
    );

    test(
      'Cont.thenMapWith is thenMap0 with eager evaluation',
      () {
        final cont1 = Cont.of<(), int>(
          10,
        ).thenMap0(() => 20);

        final cont2 = Cont.of<(), int>(10).thenMapTo(20);

        int? value1;
        int? value2;
        cont1.run((), onThen: (val) => value1 = val);
        cont2.run((), onThen: (val) => value2 = val);

        expect(value1, 20);
        expect(value2, 20);
      },
    );
  });
}
