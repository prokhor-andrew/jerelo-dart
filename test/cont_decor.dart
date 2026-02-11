import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.decor', () {
    test(
      'Cont.decor forwards value when f delegates to run',
      () {
        final cont = Cont.of<(), int>(42).decor((
          run,
          runtime,
          observer,
        ) {
          run(runtime, observer);
        });

        int? value;
        cont.run((), onThen: (val) => value = val);

        expect(value, 42);
      },
    );

    test(
      'Cont.decor forwards termination when f delegates to run',
      () {
        final errors = [ContError.capture('err1')];
        final cont = Cont.stop<(), int>(errors).decor((
          run,
          runtime,
          observer,
        ) {
          run(runtime, observer);
        });

        List<ContError>? received;
        cont.run((), onElse: (e) => received = e);

        expect(received!.length, 1);
        expect(received![0].error, 'err1');
      },
    );

    test(
      'Cont.decor can block execution by not calling run',
      () {
        final cont = Cont.of<(), int>(42).decor((
          run,
          runtime,
          observer,
        ) {
          // intentionally not calling run
        });

        int? value;
        cont.run((), onThen: (val) => value = val);

        expect(value, null);
      },
    );

    test('Cont.decor can add behavior before run', () {
      final order = <String>[];

      final cont =
          Cont.fromRun<(), int>((runtime, observer) {
            order.add('run');
            observer.onThen(10);
          }).decor((run, runtime, observer) {
            order.add('before');
            run(runtime, observer);
          });

      cont.run((), onThen: (_) => order.add('value'));

      expect(order, ['before', 'run', 'value']);
    });

    test('Cont.decor can add behavior after run', () {
      final order = <String>[];

      final cont =
          Cont.fromRun<(), int>((runtime, observer) {
            order.add('run');
            observer.onThen(10);
          }).decor((run, runtime, observer) {
            run(runtime, observer);
            order.add('after');
          });

      cont.run((), onThen: (_) => order.add('value'));

      expect(order, ['run', 'value', 'after']);
    });

    test('Cont.decor identity preserves value', () {
      final cont1 = Cont.of<(), int>(10);
      final cont2 = cont1.decor((run, runtime, observer) {
        run(runtime, observer);
      });

      int? value1;
      int? value2;

      cont1.run((), onThen: (val) => value1 = val);
      cont2.run((), onThen: (val) => value2 = val);

      expect(value1, value2);
    });

    test('Cont.decor identity preserves termination', () {
      final cont1 = Cont.stop<(), int>([
        ContError.capture('err'),
      ]);
      final cont2 = cont1.decor((run, runtime, observer) {
        run(runtime, observer);
      });

      List<ContError>? errors1;
      List<ContError>? errors2;

      cont1.run((), onElse: (e) => errors1 = e);
      cont2.run((), onElse: (e) => errors2 = e);

      expect(errors1!.length, errors2!.length);
      expect(errors1![0].error, errors2![0].error);
    });

    test('Cont.decor can be run multiple times', () {
      var callCount = 0;
      final cont = Cont.of<(), int>(5).decor((
        run,
        runtime,
        observer,
      ) {
        callCount++;
        run(runtime, observer);
      });

      int? value1;
      cont.run((), onThen: (val) => value1 = val);
      expect(value1, 5);
      expect(callCount, 1);

      int? value2;
      cont.run((), onThen: (val) => value2 = val);
      expect(value2, 5);
      expect(callCount, 2);
    });

    test('Cont.decor does not call onPanic', () {
      final cont = Cont.of<(), int>(0).decor((
        run,
        runtime,
        observer,
      ) {
        run(runtime, observer);
      });

      cont.run(
        (),
        onPanic: (_) {
          fail('Should not be called');
        },
        onThen: (_) {},
      );
    });

    test(
      'Cont.decor does not call onElse on value path',
      () {
        final cont = Cont.of<(), int>(0).decor((
          run,
          runtime,
          observer,
        ) {
          run(runtime, observer);
        });

        cont.run(
          (),
          onElse: (_) {
            fail('Should not be called');
          },
          onThen: (_) {},
        );
      },
    );

    test('Cont.decor preserves environment', () {
      int? envValue;
      final cont =
          Cont.fromRun<int, int>((runtime, observer) {
            envValue = runtime.env();
            observer.onThen(runtime.env());
          }).decor((run, runtime, observer) {
            run(runtime, observer);
          });

      int? value;
      cont.run(99, onThen: (val) => value = val);

      expect(envValue, 99);
      expect(value, 99);
    });

    test('Cont.decor cancellation prevents execution', () {
      bool decorCalled = false;

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
          }).decor((run, runtime, observer) {
            decorCalled = true;
            run(runtime, observer);
          });

      int? value;
      final token = cont.run(
        (),
        onThen: (val) => value = val,
      );

      expect(decorCalled, true);
      token.cancel();
      flush();

      expect(value, null);
    });

    test('Cont.decor calling run twice is idempotent', () {
      final values = <int>[];

      final cont = Cont.of<(), int>(7).decor((
        run,
        runtime,
        observer,
      ) {
        run(runtime, observer);
        run(runtime, observer);
      });

      cont.run((), onThen: (val) => values.add(val));

      expect(values, [7]);
    });

    test('Cont.decor can replace observer onThen', () {
      final cont =
          Cont.fromRun<(), int>((runtime, observer) {
            observer.onThen(10);
          }).decor((run, runtime, observer) {
            final newObserver = observer
                .copyUpdateOnThen<int>(
                  (val) => observer.onThen(val * 2),
                );
            run(runtime, newObserver);
          });

      int? value;
      cont.run((), onThen: (val) => value = val);

      expect(value, 20);
    });

    test('Cont.decor can replace observer onElse', () {
      final cont =
          Cont.stop<(), int>([
            ContError.capture('original'),
          ]).decor((run, runtime, observer) {
            final newObserver = observer
                .copyUpdateOnElse(
                  (errors) => observer.onThen(0),
                );
            run(runtime, newObserver);
          });

      int? value;
      List<ContError>? errors;
      cont.run(
        (),
        onThen: (val) => value = val,
        onElse: (e) => errors = e,
      );

      expect(value, 0);
      expect(errors, null);
    });

    test('Cont.decor chaining composes correctly', () {
      final order = <String>[];

      final cont = Cont.of<(), int>(1)
          .decor((run, runtime, observer) {
            order.add('outer-before');
            run(runtime, observer);
            order.add('outer-after');
          })
          .decor((run, runtime, observer) {
            order.add('inner-before');
            run(runtime, observer);
            order.add('inner-after');
          });

      cont.run((), onThen: (_) => order.add('value'));

      expect(order, [
        'inner-before',
        'outer-before',
        'value',
        'outer-after',
        'inner-after',
      ]);
    });
  });
}
