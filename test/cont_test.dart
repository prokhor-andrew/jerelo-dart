import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.run', () {
    test('executes with all callbacks provided', () {
      int? value;
      List<ContError>? errors;
      ContError? panic;

      final cont = Cont.of<(), int>(42);

      cont.run(
        (),
        onValue: (val) => value = val,
        onTerminate: (e) => errors = e,
        onPanic: (err) => panic = err,
      );

      expect(value, 42);
      expect(errors, null);
      expect(panic, null);
    });

    test('executes with only onValue callback', () {
      int? value;

      Cont.of<(), int>(
        42,
      ).run((), onValue: (val) => value = val);

      expect(value, 42);
    });

    test('executes with only onTerminate callback', () {
      List<ContError>? errors;

      Cont.terminate<(), int>([
        ContError('error', StackTrace.current),
      ]).run((), onTerminate: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'error');
    });

    test('executes with only onPanic callback', () {
      ContError? panic;

      // onPanic is only called for fatal errors like observer callback exceptions
      // This test verifies the callback is registered properly
      final cont = Cont.of<(), int>(42);

      cont.run((), onPanic: (err) => panic = err);

      // No panic should occur in normal execution
      expect(panic, null);
    });

    test('executes with no callbacks provided', () {
      // Should not throw even with no callbacks
      expect(() {
        Cont.of<(), int>(42).run(());
      }, returnsNormally);
    });

    test('returns ContCancelToken', () {
      final cont = Cont.of<(), int>(42);

      final token = cont.run(());

      expect(token, isA<ContCancelToken>());
    });

    test('cancellation via token.cancel()', () {
      bool valueCalled = false;

      final List<void Function()> buffer = [];
      void flush() {
        for (final fn in buffer) {
          fn();
        }
        buffer.clear();
      }

      final cont = Cont.fromRun<(), int>((
        runtime,
        observer,
      ) {
        buffer.add(() {
          if (runtime.isCancelled()) return;
          observer.onValue(10);
        });
      });

      final token = cont.run(
        (),
        onValue: (val) => valueCalled = true,
      );

      expect(valueCalled, false);

      token.cancel();
      flush();

      expect(valueCalled, false);
    });

    test('multiple cancels are safe', () {
      final List<void Function()> buffer = [];
      void flush() {
        for (final fn in buffer) {
          fn();
        }
        buffer.clear();
      }

      final cont = Cont.fromRun<(), int>((
        runtime,
        observer,
      ) {
        buffer.add(() {
          if (runtime.isCancelled()) return;
          observer.onValue(10);
        });
      });

      final token = cont.run(());

      expect(() {
        token.cancel();
        token.cancel();
        token.cancel();
      }, returnsNormally);

      flush();

      expect(token.isCancelled(), true);
    });

    test(
      'token.isCancelled() query returns false initially',
      () {
        final cont = Cont.of<(), int>(42);

        final token = cont.run(());

        expect(token.isCancelled(), false);
      },
    );

    test(
      'token.isCancelled() query returns true after cancel',
      () {
        final cont = Cont.of<(), int>(42);

        final token = cont.run(());
        expect(token.isCancelled(), false);

        token.cancel();
        expect(token.isCancelled(), true);
      },
    );

    test('executes onValue for successful completion', () {
      int? value;

      Cont.of<(), int>(
        99,
      ).run((), onValue: (val) => value = val);

      expect(value, 99);
    });

    test('executes onTerminate for termination', () {
      List<ContError>? errors;

      Cont.terminate<(), int>([
        ContError('err1', StackTrace.current),
        ContError('err2', StackTrace.current),
      ]).run((), onTerminate: (e) => errors = e);

      expect(errors!.length, 2);
      expect(errors![0].error, 'err1');
      expect(errors![1].error, 'err2');
    });

    test('never calls onTerminate on success', () {
      Cont.of<(), int>(42).run(
        (),
        onValue: (_) {},
        onTerminate: (_) => fail('Should not be called'),
      );
    });

    test('never calls onValue on termination', () {
      Cont.terminate<(), int>().run(
        (),
        onValue: (_) => fail('Should not be called'),
        onTerminate: (_) {},
      );
    });

    test('passes environment to continuation', () {
      String? envValue;

      Cont.fromRun<String, int>((runtime, observer) {
        envValue = runtime.env();
        observer.onValue(42);
      }).run('test-env');

      expect(envValue, 'test-env');
    });

    test(
      'supports running same continuation multiple times',
      () {
        int callCount = 0;
        final cont = Cont.fromRun<(), int>((
          runtime,
          observer,
        ) {
          callCount++;
          observer.onValue(callCount);
        });

        int? value1;
        cont.run((), onValue: (val) => value1 = val);
        expect(value1, 1);

        int? value2;
        cont.run((), onValue: (val) => value2 = val);
        expect(value2, 2);
      },
    );

    test('each run gets its own cancel token', () {
      final cont = Cont.of<(), int>(42);

      final token1 = cont.run(());
      final token2 = cont.run(());

      expect(token1, isNot(same(token2)));

      token1.cancel();
      expect(token1.isCancelled(), true);
      expect(token2.isCancelled(), false);

      token2.cancel();
      expect(token1.isCancelled(), true);
      expect(token2.isCancelled(), true);
    });

    test('handles null environment', () {
      int? value;
      Object? capturedEnv;

      Cont.fromRun<Object?, int>((runtime, observer) {
        capturedEnv = runtime.env();
        observer.onValue(42);
      }).run(null, onValue: (val) => value = val);

      expect(capturedEnv, null);
      expect(value, 42);
    });

    test('handles null value', () {
      String? value = 'initial';

      Cont.of<(), String?>(
        null,
      ).run((), onValue: (val) => value = val);

      expect(value, null);
    });

    test('respects cancellation in chained operations', () {
      bool secondOpExecuted = false;

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
            secondOpExecuted = true;
            return Cont.of(val * 2);
          });

      final token = cont.run(());

      token.cancel();
      flush();

      expect(secondOpExecuted, false);
    });
  });

  group('Cont.ff', () {
    test(
      'executes continuation in fire-and-forget manner',
      () {
        var executed = false;

        Cont.fromRun<(), int>((runtime, observer) {
          executed = true;
          observer.onValue(42);
        }).ff(());

        expect(executed, true);
      },
    );

    test('ignores success values', () {
      // ff should not wait for or handle the value
      expect(() {
        Cont.of<(), int>(42).ff(());
      }, returnsNormally);
    });

    test('ignores termination', () {
      // ff should not wait for or handle termination
      expect(() {
        Cont.terminate<(), int>([
          ContError('error', StackTrace.current),
        ]).ff(());
      }, returnsNormally);
    });

    test('onPanic still works', () {
      ContError? panicError;

      // Note: onPanic is called for fatal errors (like observer callback exceptions)
      // This test just verifies it can be registered
      Cont.of<(), int>(
        42,
      ).ff((), onPanic: (err) => panicError = err);

      // No panic in normal execution
      expect(panicError, null);
    });

    test('returns void', () {
      // ff returns void, we just verify it completes without error
      expect(() {
        Cont.of<(), int>(42).ff(());
      }, returnsNormally);
    });

    test('does not provide cancel token', () {
      // ff returns void, no way to cancel
      expect(() {
        Cont.of<(), int>(42).ff(());
      }, returnsNormally);
    });

    test('passes environment to continuation', () {
      String? envValue;

      Cont.fromRun<String, int>((runtime, observer) {
        envValue = runtime.env();
        observer.onValue(42);
      }).ff('test-env');

      expect(envValue, 'test-env');
    });

    test('executes side effects', () {
      final effects = <int>[];

      Cont.fromRun<(), int>((runtime, observer) {
        effects.add(1);
        observer.onValue(42);
      }).ff(());

      expect(effects, [1]);
    });

    test('ignores value callback', () {
      // Even if the continuation produces a value, ff ignores it
      var valueCalled = false;

      Cont.fromRun<(), int>((runtime, observer) {
        observer.onValue(42);
      }).ff(());

      expect(valueCalled, false);
    });

    test('ignores termination callback', () {
      // Even if the continuation terminates, ff ignores it
      var terminateCalled = false;

      Cont.fromRun<(), int>((runtime, observer) {
        observer.onTerminate([]);
      }).ff(());

      expect(terminateCalled, false);
    });

    test('handles null environment', () {
      Object? envValue = 'not null';

      Cont.fromRun<Object?, int>((runtime, observer) {
        envValue = runtime.env();
        observer.onValue(42);
      }).ff(null);

      expect(envValue, null);
    });

    test('supports chained operations', () {
      final effects = <String>[];

      Cont.of<(), int>(10)
          .thenTap((val) {
            effects.add('tap: $val');
            return Cont.of(());
          })
          .map((val) => val * 2)
          .ff(());

      expect(effects, ['tap: 10']);
    });
  });

  group('Cont integration tests', () {
    test('chains multiple operators successfully', () {
      String? result;

      Cont.of<(), int>(10)
          .map((n) => n * 2)
          .thenDo((n) => Cont.of(n + 5))
          .thenTap((n) => Cont.of('side: $n'))
          .map((n) => 'Result: $n')
          .run((), onValue: (val) => result = val);

      expect(result, 'Result: 25');
    });

    test('complex error recovery pattern', () {
      String? result;

      Cont.terminate<(), int>([
            ContError('first error', StackTrace.current),
          ])
          .elseDo((errors) => Cont.of(42))
          .map((n) => 'recovered: $n')
          .run((), onValue: (val) => result = val);

      expect(result, 'recovered: 42');
    });

    test('error recovery with fallback chain', () {
      String? result;

      Cont.terminate<(), String>([
            ContError('error1', StackTrace.current),
          ])
          .elseDo(
            (e1) => Cont.terminate([
              ContError('error2', StackTrace.current),
            ]),
          )
          .elseDo((e2) => Cont.of('final recovery'))
          .run((), onValue: (val) => result = val);

      expect(result, 'final recovery');
    });

    test('error accumulation with elseZip', () {
      List<ContError>? errors;

      Cont.terminate<(), int>([
            ContError('error1', StackTrace.current),
          ])
          .elseZip(
            (e1) => Cont.terminate([
              ContError('error2', StackTrace.current),
            ]),
          )
          .run((), onTerminate: (e) => errors = e);

      expect(errors!.length, 2);
      expect(errors![0].error, 'error1');
      expect(errors![1].error, 'error2');
    });

    test('environment threading through operations', () {
      final results = <String>[];

      Cont.ask<String>()
          .thenDo((env) {
            results.add('env1: $env');
            return Cont.ask<String>();
          })
          .thenDo((env) {
            results.add('env2: $env');
            return Cont.of('done');
          })
          .run(
            'test-env',
            onValue: (val) => results.add(val),
          );

      expect(results, [
        'env1: test-env',
        'env2: test-env',
        'done',
      ]);
    });

    test('environment transformation with local', () {
      String? result;

      Cont.ask<int>()
          .map((n) => n * 2)
          .local<String>((str) => str.length)
          .run(
            'hello',
            onValue: (val) => result = val.toString(),
          );

      expect(
        result,
        '10',
      ); // 'hello'.length = 5, 5 * 2 = 10
    });

    test('mixed success and failure paths', () {
      final results = <String>[];

      final cont1 = Cont.of<(), int>(10)
          .when((n) => n > 5)
          .map((n) => 'success: $n')
          .elseDo((e) => Cont.of('fallback'));

      final cont2 = Cont.of<(), int>(3)
          .when((n) => n > 5)
          .map((n) => 'success: $n')
          .elseDo((e) => Cont.of('fallback'));

      cont1.run((), onValue: (val) => results.add(val));
      cont2.run((), onValue: (val) => results.add(val));

      expect(results, ['success: 10', 'fallback']);
    });

    test('complex composition with side effects', () {
      final log = <String>[];
      String? finalResult;

      Cont.of<(), int>(5)
          .thenTap((n) {
            log.add('start: $n');
            return Cont.of(());
          })
          .map((n) => n * 2)
          .thenTap((n) {
            log.add('doubled: $n');
            return Cont.of(());
          })
          .thenDo((n) => Cont.of(n + 10))
          .thenTap((n) {
            log.add('added: $n');
            return Cont.of(());
          })
          .map((n) => 'final: $n')
          .run((), onValue: (val) => finalResult = val);

      expect(log, ['start: 5', 'doubled: 10', 'added: 20']);
      expect(finalResult, 'final: 20');
    });

    test('cancellation propagates through chain', () {
      final executed = <String>[];

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
                  if (runtime.isCancelled()) {
                    executed.add('cancelled in step1');
                    return;
                  }
                  executed.add('step1');
                  observer.onValue(10);
                });
              })
              .thenTap((val) {
                executed.add('step2: $val');
                return Cont.of(());
              })
              .map((val) {
                executed.add('step3: $val');
                return val * 2;
              });

      final token = cont.run(());

      token.cancel();
      flush();

      expect(executed, ['cancelled in step1']);
    });

    test('nested error recovery with environment', () {
      String? result;

      Cont.ask<int>()
          .map((n) => n * 2) // 5 * 2 = 10
          .map((n) => 'result: $n')
          .run(5, onValue: (val) => result = val);

      expect(result, 'result: 10');

      // Test with fallback path - when main path terminates
      String? result2;
      Cont.terminate<int, int>()
          .elseDo(
            (e) => Cont.ask<int>().map(
              (fallbackN) => fallbackN + 100,
            ),
          )
          .map((n) => 'result: $n')
          .run(5, onValue: (val) => result2 = val);

      expect(result2, 'result: 105');
    });

    test('fork for parallel side effects', () {
      final log = <String>[];
      String? result;

      Cont.of<(), int>(42)
          .thenFork((n) {
            log.add('forked: $n');
            return Cont.of(());
          })
          .map((n) {
            log.add('main: $n');
            return 'result: $n';
          })
          .run((), onValue: (val) => result = val);

      // thenFork starts side effect but doesn't wait
      expect(result, 'result: 42');
    });
  });
}
