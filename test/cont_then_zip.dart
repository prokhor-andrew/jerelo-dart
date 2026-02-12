import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.thenZip', () {
    test('combines two values', () {
      String? value;
      Cont.of<(), int>(10)
          .thenZip(
            (a) => Cont.of('value'),
            (a, b) => '$b: $a',
          )
          .run((), onThen: (val) => value = val);

      expect(value, 'value: 10');
    });

    test('executes continuations sequentially', () {
      final order = <String>[];
      int? value;

      Cont.fromRun<(), int>((runtime, observer) {
            order.add('first');
            observer.onThen(1);
          })
          .thenZip(
            (a) =>
                Cont.fromRun<(), int>((runtime, observer) {
                  order.add('second');
                  observer.onThen(2);
                }),
            (a, b) => a + b,
          )
          .run((), onThen: (val) => value = val);

      expect(order, ['first', 'second']);
      expect(value, 3);
    });

    test('provides first value to combine function', () {
      int? combined;
      Cont.of<(), int>(5)
          .thenZip((a) => Cont.of(a * 2), (a, b) {
            combined = a + b;
            return combined!;
          })
          .run(());

      expect(combined, 15); // 5 + 10
    });

    test('passes through first termination', () {
      final errors = [ContError.capture('err1')];
      List<ContError>? received;

      Cont.stop<(), int>(errors)
          .thenZip(
            (a) => Cont.of('value'),
            (a, b) => '$a $b',
          )
          .run((), onElse: (e) => received = e);

      expect(received!.length, 1);
      expect(received![0].error, 'err1');
    });

    test(
      'terminates when second continuation terminates',
      () {
        final cont = Cont.of<(), int>(42).thenZip(
          (a) => Cont.stop<(), String>([
            ContError.capture('second error'),
          ]),
          (a, b) => '$b: $a',
        );

        List<ContError>? errors;
        cont.run(
          (),
          onThen: (_) => fail('onThen must not be called'),
          onElse: (e) => errors = e,
        );

        expect(errors!.length, 1);
        expect(errors![0].error, 'second error');
      },
    );

    test('terminates when continuation builder throws', () {
      final cont = Cont.of<(), int>(0).thenZip((val) {
        throw 'Thrown Error';
      }, (a, b) => a);

      ContError? error;
      cont.run(
        (),
        onElse: (errors) => error = errors.first,
      );

      expect(error!.error, 'Thrown Error');
    });

    test('terminates when combine function throws', () {
      final cont = Cont.of<(), int>(5).thenZip(
        (a) => Cont.of(10),
        (a, b) {
          throw 'Combine Error';
        },
      );

      ContError? error;
      cont.run(
        (),
        onElse: (errors) => error = errors.first,
      );

      expect(error!.error, 'Combine Error');
    });

    test('never executes second on first termination', () {
      bool secondCalled = false;
      Cont.stop<(), int>()
          .thenZip((a) {
            secondCalled = true;
            return Cont.of('value');
          }, (a, b) => '$a $b')
          .run((), onElse: (_) {});

      expect(secondCalled, false);
    });

    test('transforms value types', () {
      String? value;

      Cont.of<(), int>(42)
          .thenZip(
            (n) => Cont.of(n.toString()),
            (num, str) => 'number: $num, string: $str',
          )
          .run((), onThen: (val) => value = val);

      expect(value, 'number: 42, string: 42');
    });

    test('supports multiple runs', () {
      final cont = Cont.of<(), int>(
        5,
      ).thenZip((a) => Cont.of(a * 3), (a, b) => a + b);

      int? value1;
      cont.run((), onThen: (val) => value1 = val);
      expect(value1, 20); // 5 + 15

      int? value2;
      cont.run((), onThen: (val) => value2 = val);
      expect(value2, 20);
    });

    test('never calls onPanic', () {
      Cont.of<(), int>(0)
          .thenZip((a) => Cont.of(5), (a, b) => a + b)
          .run(
            (),
            onPanic: (_) => fail('Should not be called'),
            onThen: (_) {},
          );
    });

    test(
      'prevents second continuation after cancellation',
      () {
        bool secondCalled = false;

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
            }).thenZip((val) {
              secondCalled = true;
              return Cont.of(20);
            }, (a, b) => a + b);

        int? value;
        final token = cont.run(
          (),
          onThen: (val) => value = val,
        );

        token.cancel();
        flush();

        expect(secondCalled, false);
        expect(value, null);
      },
    );

    test('supports Cont<E, Never> second continuation', () {
      List<ContError>? errors;
      final cont = Cont.of<(), int>(42).thenZip(
        (a) => Cont.fromRun<(), Never>((runtime, observer) {
          observer.onElse([
            ContError.capture("never error"),
          ]);
        }),
        (a, b) => b,
      );

      cont.run(
        (),
        onElse: (e) => errors = e,
        onThen: (v) {
          fail('Should not be called');
        },
      );

      expect(errors![0].error, "never error");
    });

    test('thenZip0 ignores first value', () {
      String? value1;
      String? value2;

      final cont1 = Cont.of<(), int>(
        10,
      ).thenZip0(() => Cont.of('test'), (a, b) => '$b: $a');
      final cont2 = Cont.of<(), int>(
        10,
      ).thenZip((_) => Cont.of('test'), (a, b) => '$b: $a');

      cont1.run((), onThen: (val) => value1 = val);
      cont2.run((), onThen: (val) => value2 = val);

      expect(value1, value2);
      expect(value1, 'test: 10');
    });
  });
}
