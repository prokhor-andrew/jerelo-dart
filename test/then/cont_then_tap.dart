import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.thenTap', () {
    test('preserves original value', () {
      int? value;
      Cont.of<(), int>(42)
          .thenTap((a) => Cont.of('side effect'))
          .run((), onThen: (val) => value = val);

      expect(value, 42);
    });

    test('executes side effect', () {
      var sideEffectValue = 0;
      Cont.of<(), int>(10)
          .thenTap(
            (a) => Cont.of<(), ()>(()).thenMap((_) {
              sideEffectValue = a * 2;
              return ();
            }),
          )
          .run(());

      expect(sideEffectValue, 20);
    });

    test('passes through termination', () {
      final errors = [ContError.capture('err1')];
      List<ContError>? received;

      Cont.stop<(), int>(errors)
          .thenTap((a) => Cont.of('side effect'))
          .run((), onElse: (e) => received = e);

      expect(received!.length, 1);
      expect(received![0].error, 'err1');
    });

    test('terminates when side effect terminates', () {
      final cont = Cont.of<(), int>(42).thenTap(
        (a) => Cont.stop<(), String>([
          ContError.capture('side effect error'),
        ]),
      );

      List<ContError>? errors;
      cont.run(
        (),
        onThen: (_) => fail('onThen must not be called'),
        onElse: (e) => errors = e,
      );

      expect(errors!.length, 1);
      expect(errors![0].error, 'side effect error');
    });

    test('returns original value after side effect', () {
      String? value;
      Cont.of<(), String>('original')
          .thenTap((a) => Cont.of(999))
          .run((), onThen: (val) => value = val);

      expect(value, 'original');
    });

    test('terminates when function throws', () {
      final cont = Cont.of<(), int>(0).thenTap((val) {
        throw 'Thrown Error';
      });

      ContError? error;
      cont.run(
        (),
        onElse: (errors) => error = errors.first,
      );

      expect(error!.error, 'Thrown Error');
    });

    test('supports multiple runs', () {
      var callCount = 0;
      final cont = Cont.of<(), int>(10).thenTap(
        (a) => Cont.of<(), ()>(()).thenMap((_) {
          callCount++;
          return ();
        }),
      );

      int? value1;
      cont.run((), onThen: (val) => value1 = val);
      expect(value1, 10);
      expect(callCount, 1);

      int? value2;
      cont.run((), onThen: (val) => value2 = val);
      expect(value2, 10);
      expect(callCount, 2);
    });

    test('never calls onPanic', () {
      Cont.of<(), int>(0)
          .thenTap((val) => Cont.of(val + 5))
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
              observer.onThen(10);
            });
          }).thenTap((val) {
            sideEffectCalled = true;
            return Cont.of(());
          });

      int? value;
      final token = cont.run(
        (),
        onThen: (val) => value = val,
      );

      token.cancel();
      flush();

      expect(sideEffectCalled, false);
      expect(value, null);
    });

    test('supports Cont<E, Never> side effect', () {
      List<ContError>? errors;
      final cont = Cont.of<(), int>(42).thenTap(
        (a) => Cont.fromRun<(), Never>((runtime, observer) {
          observer.onElse([
            ContError.capture("never error"),
          ]);
        }),
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

    test('thenTap0 ignores input value', () {
      int? value1;
      int? value2;
      var count1 = 0;
      var count2 = 0;

      final cont1 = Cont.of<(), int>(10).thenTap0(
        () => Cont.of<(), ()>(()).thenMap((_) {
          count1++;
          return ();
        }),
      );
      final cont2 = Cont.of<(), int>(10).thenTap(
        (_) => Cont.of<(), ()>(()).thenMap((_) {
          count2++;
          return ();
        }),
      );

      cont1.run((), onThen: (val) => value1 = val);
      cont2.run((), onThen: (val) => value2 = val);

      expect(value1, value2);
      expect(count1, 1);
      expect(count2, 1);
    });

    test('side effect runs before main value (timing)', () {
      final order = <String>[];
      int? result;

      Cont.of<(), int>(42)
          .thenTap((val) {
            order.add('side-effect: $val');
            return Cont.of(());
          })
          .thenMap((val) {
            order.add('main-value: $val');
            return val;
          })
          .run(
            (),
            onThen: (val) {
              order.add('final: $val');
              result = val;
            },
          );

      expect(result, 42);
      expect(order, [
        'side-effect: 42',
        'main-value: 42',
        'final: 42',
      ]);
    });

    test(
      'verifies side effect completes before continuation proceeds',
      () {
        final order = <String>[];

        Cont.of<(), int>(10)
            .thenTap((val) {
              order.add('tap1');
              return Cont.of(());
            })
            .thenTap((val) {
              order.add('tap2');
              return Cont.of(());
            })
            .thenDo((val) {
              order.add('then');
              return Cont.of(val);
            })
            .run((), onThen: (_) => order.add('value'));

        expect(order, ['tap1', 'tap2', 'then', 'value']);
      },
    );

    test('timing with deferred side effect', () {
      final order = <String>[];
      int? result;

      Cont.of<(), int>(5)
          .thenTap((val) {
            return Cont.fromDeferred(() {
              order.add('deferred-side-effect');
              return Cont.of(());
            });
          })
          .thenMap((val) {
            order.add('map');
            return val * 2;
          })
          .run(
            (),
            onThen: (val) {
              order.add('value: $val');
              result = val;
            },
          );

      expect(result, 10);
      expect(order, [
        'deferred-side-effect',
        'map',
        'value: 10',
      ]);
    });
  });
}
