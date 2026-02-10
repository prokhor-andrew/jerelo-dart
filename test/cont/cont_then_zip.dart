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
          .run((), onValue: (val) => value = val);

      expect(value, 'value: 10');
    });

    test('executes continuations sequentially', () {
      final order = <String>[];
      int? value;

      Cont.fromRun<(), int>((runtime, observer) {
            order.add('first');
            observer.onValue(1);
          })
          .thenZip(
            (a) =>
                Cont.fromRun<(), int>((runtime, observer) {
                  order.add('second');
                  observer.onValue(2);
                }),
            (a, b) => a + b,
          )
          .run((), onValue: (val) => value = val);

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

      Cont.terminate<(), int>(errors)
          .thenZip(
            (a) => Cont.of('value'),
            (a, b) => '$a $b',
          )
          .run((), onTerminate: (e) => received = e);

      expect(received!.length, 1);
      expect(received![0].error, 'err1');
    });

    test(
      'terminates when second continuation terminates',
      () {
        final cont = Cont.of<(), int>(42).thenZip(
          (a) => Cont.terminate<(), String>([
            ContError.capture('second error'),
          ]),
          (a, b) => '$b: $a',
        );

        List<ContError>? errors;
        cont.run(
          (),
          onValue: (_) =>
              fail('onValue must not be called'),
          onTerminate: (e) => errors = e,
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
        onTerminate: (errors) => error = errors.first,
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
        onTerminate: (errors) => error = errors.first,
      );

      expect(error!.error, 'Combine Error');
    });

    test('never executes second on first termination', () {
      bool secondCalled = false;
      Cont.terminate<(), int>()
          .thenZip((a) {
            secondCalled = true;
            return Cont.of('value');
          }, (a, b) => '$a $b')
          .run((), onTerminate: (_) {});

      expect(secondCalled, false);
    });

    test('transforms value types', () {
      String? value;

      Cont.of<(), int>(42)
          .thenZip(
            (n) => Cont.of(n.toString()),
            (num, str) => 'number: $num, string: $str',
          )
          .run((), onValue: (val) => value = val);

      expect(value, 'number: 42, string: 42');
    });

    test('supports chaining', () {
      String? value;

      Cont.of<(), int>(1)
          .thenZip((a) => Cont.of(a + 1), (a, b) => a + b)
          .thenZip(
            (sum) => Cont.of(sum * 2),
            (prev, doubled) => '$prev -> $doubled',
          )
          .run((), onValue: (val) => value = val);

      expect(value, '2 -> 4');
    });

    test('supports multiple runs', () {
      final cont = Cont.of<(), int>(
        5,
      ).thenZip((a) => Cont.of(a * 3), (a, b) => a + b);

      int? value1;
      cont.run((), onValue: (val) => value1 = val);
      expect(value1, 20); // 5 + 15

      int? value2;
      cont.run((), onValue: (val) => value2 = val);
      expect(value2, 20);
    });

    test('supports null values', () {
      String? value;

      Cont.of<(), String?>('first')
          .thenZip(
            (a) => Cont.of<(), String?>(null),
            (a, b) => 'a=$a, b=$b',
          )
          .run((), onValue: (val) => value = val);

      expect(value, 'a=first, b=null');
    });

    test('never calls onPanic', () {
      Cont.of<(), int>(0)
          .thenZip((a) => Cont.of(5), (a, b) => a + b)
          .run(
            (),
            onPanic: (_) => fail('Should not be called'),
            onValue: (_) {},
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
                observer.onValue(10);
              });
            }).thenZip((val) {
              secondCalled = true;
              return Cont.of(20);
            }, (a, b) => a + b);

        int? value;
        final token = cont.run(
          (),
          onValue: (val) => value = val,
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
          observer.onTerminate([
            ContError.capture("never error"),
          ]);
        }),
        (a, b) => b,
      );

      cont.run(
        (),
        onTerminate: (e) => errors = e,
        onValue: (v) {
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

      cont1.run((), onValue: (val) => value1 = val);
      cont2.run((), onValue: (val) => value2 = val);

      expect(value1, value2);
      expect(value1, 'test: 10');
    });
  });
}
