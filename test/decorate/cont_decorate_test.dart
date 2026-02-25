import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.decorate', () {
    test('forwards value when f delegates to run', () {
      final cont = Cont.of<(), String, int>(42).decorate((
        run,
        runtime,
        observer,
      ) {
        run(runtime, observer);
      });

      int? value;
      cont.run((), onThen: (val) => value = val);

      expect(value, 42);
    });

    test('forwards error when f delegates to run', () {
      final cont =
          Cont.error<(), String, int>('err1').decorate((
        run,
        runtime,
        observer,
      ) {
        run(runtime, observer);
      });

      String? error;
      cont.run((), onElse: (e) => error = e);

      expect(error, 'err1');
    });

    test('can block execution by not calling run', () {
      final cont = Cont.of<(), String, int>(42).decorate((
        run,
        runtime,
        observer,
      ) {
        // intentionally not calling run
      });

      int? value;
      cont.run((), onThen: (val) => value = val);

      expect(value, null);
    });

    test('can add behavior before run', () {
      final order = <String>[];

      final cont =
          Cont.fromRun<(), String, int>((runtime, observer) {
            order.add('run');
            observer.onThen(10);
          }).decorate((run, runtime, observer) {
            order.add('before');
            run(runtime, observer);
          });

      cont.run((), onThen: (_) => order.add('value'));

      expect(order, ['before', 'run', 'value']);
    });

    test('can add behavior after run', () {
      final order = <String>[];

      final cont =
          Cont.fromRun<(), String, int>((runtime, observer) {
            order.add('run');
            observer.onThen(10);
          }).decorate((run, runtime, observer) {
            run(runtime, observer);
            order.add('after');
          });

      cont.run((), onThen: (_) => order.add('value'));

      expect(order, ['run', 'value', 'after']);
    });

    test('identity preserves value', () {
      final cont1 = Cont.of<(), String, int>(10);
      final cont2 =
          cont1.decorate((run, runtime, observer) {
        run(runtime, observer);
      });

      int? value1;
      int? value2;

      cont1.run((), onThen: (val) => value1 = val);
      cont2.run((), onThen: (val) => value2 = val);

      expect(value1, value2);
    });

    test('identity preserves error', () {
      final cont1 = Cont.error<(), String, int>('err');
      final cont2 =
          cont1.decorate((run, runtime, observer) {
        run(runtime, observer);
      });

      String? error1;
      String? error2;

      cont1.run((), onElse: (e) => error1 = e);
      cont2.run((), onElse: (e) => error2 = e);

      expect(error1, error2);
    });

    test('can be run multiple times', () {
      var callCount = 0;
      final cont = Cont.of<(), String, int>(5).decorate((
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

    test('does not call onPanic', () {
      final cont = Cont.of<(), String, int>(0).decorate((
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

    test('does not call onElse on value path', () {
      final cont = Cont.of<(), String, int>(0).decorate((
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
    });

    test('preserves environment', () {
      int? envValue;
      final cont =
          Cont.fromRun<int, String, int>((runtime, observer) {
            envValue = runtime.env();
            observer.onThen(runtime.env());
          }).decorate((run, runtime, observer) {
            run(runtime, observer);
          });

      int? value;
      cont.run(99, onThen: (val) => value = val);

      expect(envValue, 99);
      expect(value, 99);
    });

    test('cancellation prevents execution', () {
      bool decorCalled = false;

      final List<void Function()> buffer = [];
      void flush() {
        for (final value in buffer) {
          value();
        }
        buffer.clear();
      }

      final cont =
          Cont.fromRun<(), String, int>((runtime, observer) {
            buffer.add(() {
              if (runtime.isCancelled()) return;
              observer.onThen(10);
            });
          }).decorate((run, runtime, observer) {
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

    test('calling run twice is idempotent', () {
      final values = <int>[];

      final cont = Cont.of<(), String, int>(7).decorate((
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

    test('can replace observer onThen', () {
      final cont =
          Cont.fromRun<(), String, int>((runtime, observer) {
            observer.onThen(10);
          }).decorate((run, runtime, observer) {
            final newObserver = observer.copyUpdateOnThen<int>(
              (val) => observer.onThen(val * 2),
            );
            run(runtime, newObserver);
          });

      int? value;
      cont.run((), onThen: (val) => value = val);

      expect(value, 20);
    });

    test('can replace observer onElse', () {
      final cont =
          Cont.error<(), String, int>('original').decorate((
        run,
        runtime,
        observer,
      ) {
        final newObserver =
            observer.copyUpdateOnElse<String>(
          (error) => observer.onThen(0),
        );
        run(runtime, newObserver);
      });

      int? value;
      String? error;
      cont.run(
        (),
        onThen: (val) => value = val,
        onElse: (e) => error = e,
      );

      expect(value, 0);
      expect(error, null);
    });

    test('chaining composes correctly', () {
      final order = <String>[];

      final cont = Cont.of<(), String, int>(1)
          .decorate((run, runtime, observer) {
            order.add('outer-before');
            run(runtime, observer);
            order.add('outer-after');
          })
          .decorate((run, runtime, observer) {
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
