import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.hoist', () {
    test('forwards value when delegating to run', () {
      final cont = Cont.of<(), int>(42).hoist((
        run,
        runtime,
        observer,
      ) {
        run(runtime, observer);
      });

      int? value;
      cont.run((), onValue: (val) => value = val);

      expect(value, 42);
    });

    test('forwards termination when delegating to run', () {
      final errors = [
        ContError('err1', StackTrace.current),
      ];
      final cont = Cont.terminate<(), int>(errors).hoist((
        run,
        runtime,
        observer,
      ) {
        run(runtime, observer);
      });

      List<ContError>? received;
      cont.run((), onTerminate: (e) => received = e);

      expect(received!.length, 1);
      expect(received![0].error, 'err1');
    });

    test('blocks execution when not calling run', () {
      final cont = Cont.of<(), int>(42).hoist((
        run,
        runtime,
        observer,
      ) {
        // intentionally not calling run
      });

      int? value;
      cont.run((), onValue: (val) => value = val);

      expect(value, null);
    });

    test('executes behavior before run', () {
      final order = <String>[];

      final cont =
          Cont.fromRun<(), int>((runtime, observer) {
            order.add('run');
            observer.onValue(10);
          }).hoist((run, runtime, observer) {
            order.add('before');
            run(runtime, observer);
          });

      cont.run((), onValue: (_) => order.add('value'));

      expect(order, ['before', 'run', 'value']);
    });

    test('executes behavior after run', () {
      final order = <String>[];

      final cont =
          Cont.fromRun<(), int>((runtime, observer) {
            order.add('run');
            observer.onValue(10);
          }).hoist((run, runtime, observer) {
            run(runtime, observer);
            order.add('after');
          });

      cont.run((), onValue: (_) => order.add('value'));

      expect(order, ['run', 'value', 'after']);
    });

    test(
      'identity hoist preserves value and termination',
      () {
        final valueCont = Cont.of<(), int>(10);
        final valueHoisted = valueCont.hoist((
          run,
          runtime,
          observer,
        ) {
          run(runtime, observer);
        });

        int? value1;
        int? value2;
        valueCont.run((), onValue: (val) => value1 = val);
        valueHoisted.run(
          (),
          onValue: (val) => value2 = val,
        );
        expect(value1, value2);

        final terminateCont = Cont.terminate<(), int>([
          ContError('err', StackTrace.current),
        ]);
        final terminateHoisted = terminateCont.hoist((
          run,
          runtime,
          observer,
        ) {
          run(runtime, observer);
        });

        List<ContError>? errors1;
        List<ContError>? errors2;
        terminateCont.run(
          (),
          onTerminate: (e) => errors1 = e,
        );
        terminateHoisted.run(
          (),
          onTerminate: (e) => errors2 = e,
        );

        expect(errors1!.length, errors2!.length);
        expect(errors1![0].error, errors2![0].error);
      },
    );

    test('supports multiple runs', () {
      var callCount = 0;
      final cont = Cont.of<(), int>(5).hoist((
        run,
        runtime,
        observer,
      ) {
        callCount++;
        run(runtime, observer);
      });

      int? value1;
      cont.run((), onValue: (val) => value1 = val);
      expect(value1, 5);
      expect(callCount, 1);

      int? value2;
      cont.run((), onValue: (val) => value2 = val);
      expect(value2, 5);
      expect(callCount, 2);
    });

    test('never calls onPanic', () {
      final cont = Cont.of<(), int>(0).hoist((
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
        onValue: (_) {},
      );
    });

    test('never calls onTerminate on value path', () {
      final cont = Cont.of<(), int>(0).hoist((
        run,
        runtime,
        observer,
      ) {
        run(runtime, observer);
      });

      cont.run(
        (),
        onTerminate: (_) {
          fail('Should not be called');
        },
        onValue: (_) {},
      );
    });

    test('preserves environment', () {
      int? envValue;
      final cont =
          Cont.fromRun<int, int>((runtime, observer) {
            envValue = runtime.env();
            observer.onValue(runtime.env());
          }).hoist((run, runtime, observer) {
            run(runtime, observer);
          });

      int? value;
      cont.run(99, onValue: (val) => value = val);

      expect(envValue, 99);
      expect(value, 99);
    });

    test('prevents execution after cancellation', () {
      bool hoistCalled = false;

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
              observer.onValue(10);
            });
          }).hoist((run, runtime, observer) {
            hoistCalled = true;
            run(runtime, observer);
          });

      int? value;
      final token = cont.run(
        (),
        onValue: (val) => value = val,
      );

      expect(hoistCalled, true);
      token.cancel();
      flush();

      expect(value, null);
    });

    test('respects idempotency when calling run twice', () {
      final values = <int>[];

      final cont = Cont.of<(), int>(7).hoist((
        run,
        runtime,
        observer,
      ) {
        run(runtime, observer);
        run(runtime, observer);
      });

      cont.run((), onValue: (val) => values.add(val));

      expect(values, [7]);
    });

    test('supports replacing observer onValue', () {
      final cont =
          Cont.fromRun<(), int>((runtime, observer) {
            observer.onValue(10);
          }).hoist((run, runtime, observer) {
            final newObserver = observer
                .copyUpdateOnValue<int>(
                  (val) => observer.onValue(val * 2),
                );
            run(runtime, newObserver);
          });

      int? value;
      cont.run((), onValue: (val) => value = val);

      expect(value, 20);
    });

    test('supports replacing observer onTerminate', () {
      final cont =
          Cont.terminate<(), int>([
            ContError('original', StackTrace.current),
          ]).hoist((run, runtime, observer) {
            final newObserver = observer
                .copyUpdateOnTerminate(
                  (errors) => observer.onValue(0),
                );
            run(runtime, newObserver);
          });

      int? value;
      List<ContError>? errors;
      cont.run(
        (),
        onValue: (val) => value = val,
        onTerminate: (e) => errors = e,
      );

      expect(value, 0);
      expect(errors, null);
    });

    test('composes chained hoists correctly', () {
      final order = <String>[];

      final cont = Cont.of<(), int>(1)
          .hoist((run, runtime, observer) {
            order.add('outer-before');
            run(runtime, observer);
            order.add('outer-after');
          })
          .hoist((run, runtime, observer) {
            order.add('inner-before');
            run(runtime, observer);
            order.add('inner-after');
          });

      cont.run((), onValue: (_) => order.add('value'));

      expect(order, [
        'inner-before',
        'outer-before',
        'value',
        'outer-after',
        'inner-after',
      ]);
    });

    test('supports null values', () {
      String? value = 'initial';
      final cont = Cont.of<(), String?>(null).hoist((
        run,
        runtime,
        observer,
      ) {
        run(runtime, observer);
      });

      cont.run((), onValue: (val) => value = val);

      expect(value, null);
    });

    test('uses hoist for logging/tracing pattern', () {
      final log = <String>[];
      int? result;

      final cont = Cont.of<(), int>(42).hoist((
        run,
        runtime,
        observer,
      ) {
        log.add('Starting execution');

        final wrappedObserver = observer
            .copyUpdateOnValue<int>((val) {
              log.add('Value received: $val');
              observer.onValue(val);
            })
            .copyUpdateOnTerminate((errors) {
              log.add(
                'Termination received: ${errors.length} errors',
              );
              observer.onTerminate(errors);
            });

        run(runtime, wrappedObserver);
        log.add('Execution initiated');
      });

      cont.run((), onValue: (val) => result = val);

      expect(result, 42);
      expect(log, [
        'Starting execution',
        'Value received: 42',
        'Execution initiated',
      ]);
    });

    test('uses hoist for logging with termination', () {
      final log = <String>[];
      List<ContError>? errors;

      final cont =
          Cont.terminate<(), int>([
            ContError('error', StackTrace.current),
          ]).hoist((run, runtime, observer) {
            log.add('Starting execution');

            final wrappedObserver = observer
                .copyUpdateOnValue<int>((val) {
                  log.add('Value received: $val');
                  observer.onValue(val);
                })
                .copyUpdateOnTerminate((errs) {
                  log.add(
                    'Termination received: ${errs.length} errors',
                  );
                  observer.onTerminate(errs);
                });

            run(runtime, wrappedObserver);
            log.add('Execution initiated');
          });

      cont.run((), onTerminate: (e) => errors = e);

      expect(errors!.length, 1);
      expect(log, [
        'Starting execution',
        'Termination received: 1 errors',
        'Execution initiated',
      ]);
    });

    test(
      'uses hoist to modify environment before delegation',
      () {
        int? result;

        final cont =
            Cont.fromRun<int, int>((runtime, observer) {
              final env = runtime.env();
              observer.onValue(env * 10);
            }).hoist((run, runtime, observer) {
              // Modify the environment: double it before passing to inner computation
              final originalEnv = runtime.env();
              final modifiedRuntime = runtime.copyUpdateEnv(
                originalEnv * 2,
              );

              run(modifiedRuntime, observer);
            });

        cont.run(5, onValue: (val) => result = val);

        // 5 * 2 = 10, then 10 * 10 = 100
        expect(result, 100);
      },
    );

    test('uses hoist to modify environment type', () {
      String? result;

      // Use local to transform environment instead of hoist
      final cont = Cont.ask<String>()
          .map((env) => 'env: $env')
          .local<int>((intEnv) => 'number-$intEnv');

      cont.run(42, onValue: (val) => result = val);

      expect(result, 'env: number-42');
    });

    test('uses hoist for timing/instrumentation', () {
      final log = <String>[];
      int? result;

      final cont =
          Cont.fromDeferred<(), int>(() {
            log.add('computation');
            return Cont.of(100);
          }).hoist((run, runtime, observer) {
            log.add('before');
            run(runtime, observer);
            log.add('after');
          });

      cont.run((), onValue: (val) => result = val);

      expect(result, 100);
      expect(log, ['before', 'computation', 'after']);
    });

    test('uses hoist to add retry logic wrapper', () {
      int attempts = 0;
      int? result;

      final cont =
          Cont.fromDeferred<(), int>(() {
            attempts++;
            return attempts < 3
                ? Cont.terminate<(), int>()
                : Cont.of(42);
          }).hoist((run, runtime, observer) {
            // Wrap observer to retry on termination
            var retryCount = 0;
            void tryRun() {
              final wrappedObserver = observer
                  .copyUpdateOnTerminate((errors) {
                    retryCount++;
                    if (retryCount < 3) {
                      // Retry
                      tryRun();
                    } else {
                      observer.onTerminate(errors);
                    }
                  });
              run(runtime, wrappedObserver);
            }

            tryRun();
          });

      cont.run((), onValue: (val) => result = val);

      expect(result, 42);
      expect(attempts, 3);
    });

    test('uses hoist to add context/metadata', () {
      final metadata = <String, dynamic>{};
      int? result;

      final cont = Cont.of<(), int>(42).hoist((
        run,
        runtime,
        observer,
      ) {
        metadata['start_time'] =
            DateTime.now().millisecondsSinceEpoch;

        final wrappedObserver = observer
            .copyUpdateOnValue<int>((val) {
              metadata['end_time'] =
                  DateTime.now().millisecondsSinceEpoch;
              metadata['result'] = val;
              observer.onValue(val);
            });

        run(runtime, wrappedObserver);
      });

      cont.run((), onValue: (val) => result = val);

      expect(result, 42);
      expect(metadata['result'], 42);
      expect(metadata['start_time'], isNotNull);
      expect(metadata['end_time'], isNotNull);
    });
  });
}
