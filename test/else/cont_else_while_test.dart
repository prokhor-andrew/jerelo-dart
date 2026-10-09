import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.elseWhile', () {
    test('retries while predicate is true', () {
      int attempts = 0;

      Cont.fromDeferred<(), int>(() {
            attempts++;
            if (attempts < 3) {
              return Cont.stop<(), int>([
                ContError.capture('retry $attempts'),
              ]);
            }
            return Cont.of(attempts);
          })
          .elseWhile(
            (errors) => errors.first.error != 'retry 3',
          )
          .run((), onThen: (_) {});

      expect(attempts, 3);
    });

    test('succeeds when retry eventually succeeds', () {
      int attempts = 0;
      int? value;

      Cont.fromDeferred<(), int>(() {
            attempts++;
            if (attempts < 4) {
              return Cont.stop<(), int>([
                ContError.capture('error'),
              ]);
            }
            return Cont.of(42);
          })
          .elseWhile((errors) => true)
          .run((), onThen: (val) => value = val);

      expect(value, 42);
      expect(attempts, 4);
    });

    test('stops when predicate returns false', () {
      int attempts = 0;
      List<ContError>? errors;

      Cont.fromDeferred<(), int>(() {
            attempts++;
            return Cont.stop<(), int>([
              ContError.capture('error $attempts'),
            ]);
          })
          .elseWhile((errors) => attempts < 3)
          .run((), onElse: (e) => errors = e);

      expect(attempts, 3);
      expect(errors![0].error, 'error 3');
    });

    test(
      'does not retry when predicate is immediately false',
      () {
        int attempts = 0;
        List<ContError>? errors;

        Cont.fromDeferred<(), int>(() {
              attempts++;
              return Cont.stop<(), int>([
                ContError.capture('error'),
              ]);
            })
            .elseWhile((_) => false)
            .run((), onElse: (e) => errors = e);

        expect(attempts, 1);
        expect(errors![0].error, 'error');
      },
    );

    test(
      'passes through value without executing predicate',
      () {
        bool predicateCalled = false;
        int? value;

        Cont.of<(), int>(42)
            .elseWhile((errors) {
              predicateCalled = true;
              return true;
            })
            .run((), onThen: (val) => value = val);

        expect(predicateCalled, false);
        expect(value, 42);
      },
    );

    test('terminates when predicate throws', () {
      ContError? error;

      Cont.stop<(), int>([ContError.capture('err')])
          .elseWhile((errors) {
            throw 'Predicate Error';
          })
          .run(
            (),
            onElse: (errors) => error = errors.first,
          );

      expect(error!.error, 'Predicate Error');
    });

    test('never calls onPanic', () {
      int attempts = 0;

      Cont.fromDeferred<(), int>(() {
            attempts++;
            if (attempts < 3) {
              return Cont.stop<(), int>([
                ContError.capture('error'),
              ]);
            }
            return Cont.of(attempts);
          })
          .elseWhile((_) => true)
          .run(
            (),
            onPanic: (_) => fail('Should not be called'),
            onThen: (_) {},
          );

      expect(attempts, 3);
    });

    test('supports multiple runs', () {
      int attempts = 0;
      final cont = Cont.fromDeferred<(), int>(() {
        attempts++;
        if (attempts < 3) {
          return Cont.stop<(), int>([
            ContError.capture('error'),
          ]);
        }
        return Cont.of(attempts);
      }).elseWhile((_) => true);

      int? value1;
      cont.run((), onThen: (val) => value1 = val);
      expect(value1, 3);

      attempts = 0;
      int? value2;
      cont.run((), onThen: (val) => value2 = val);
      expect(value2, 3);
    });

    test('stops loop after cancellation', () {
      int iterations = 0;
      bool cancelled = false;

      final List<void Function()> buffer = [];
      void flush() {
        final copy = buffer.toList();
        buffer.clear();
        for (final fn in copy) {
          fn();
        }
      }

      final cont = Cont.fromRun<(), int>((
        runtime,
        observer,
      ) {
        buffer.add(() {
          if (cancelled || runtime.isCancelled()) {
            observer.onElse([]);
            return;
          }
          iterations++;
          observer.onElse([
            ContError.capture('error $iterations'),
          ]);
        });
      }).elseWhile((_) => true);

      cont.run((), onThen: (_) {}, onElse: (_) {});

      flush(); // iteration 1
      expect(iterations, 1);

      flush(); // iteration 2
      expect(iterations, 2);

      cancelled = true;
      flush(); // cancelled, terminates
      expect(iterations, 2);
    });
  });

  group('Cont.elseWhile0', () {
    test(
      'retries while zero-argument predicate is true',
      () {
        int attempts = 0;
        int? value;

        Cont.fromDeferred<(), int>(() {
              attempts++;
              if (attempts < 3) {
                return Cont.stop<(), int>([
                  ContError.capture('error'),
                ]);
              }
              return Cont.of(attempts);
            })
            .elseWhile0(() => true)
            .run((), onThen: (val) => value = val);

        expect(value, 3);
      },
    );

    test('behaves like elseWhile with ignored errors', () {
      int attempts1 = 0;
      int attempts2 = 0;

      Cont.fromDeferred<(), int>(() {
        attempts1++;
        if (attempts1 < 3) {
          return Cont.stop<(), int>([
            ContError.capture('error'),
          ]);
        }
        return Cont.of(attempts1);
      }).elseWhile0(() => true).run((), onThen: (_) {});

      Cont.fromDeferred<(), int>(() {
        attempts2++;
        if (attempts2 < 3) {
          return Cont.stop<(), int>([
            ContError.capture('error'),
          ]);
        }
        return Cont.of(attempts2);
      }).elseWhile((_) => true).run((), onThen: (_) {});

      expect(attempts1, attempts2);
    });

    test('stops when predicate returns false', () {
      int attempts = 0;
      List<ContError>? errors;

      Cont.fromDeferred<(), int>(() {
            attempts++;
            return Cont.stop<(), int>([
              ContError.capture('error'),
            ]);
          })
          .elseWhile0(() => attempts < 3)
          .run((), onElse: (e) => errors = e);

      expect(attempts, 3);
      expect(errors, isNotNull);
    });
  });

  group('Cont.elseWhileWithEnv', () {
    test('provides both env and errors to predicate', () {
      String? receivedEnv;
      List<ContError>? receivedErrors;

      Cont.stop<String, int>([ContError.capture('err')])
          .elseWhileWithEnv((env, errors) {
            receivedEnv = env;
            receivedErrors = errors;
            return false; // stop immediately
          })
          .run('hello', onElse: (_) {});

      expect(receivedEnv, 'hello');
      expect(receivedErrors!.length, 1);
      expect(receivedErrors![0].error, 'err');
    });

    test('retries using env-based condition', () {
      int attempts = 0;
      int? value;

      Cont.fromDeferred<int, int>(() {
            attempts++;
            if (attempts < 3) {
              return Cont.stop<int, int>([
                ContError.capture('error'),
              ]);
            }
            return Cont.of(attempts);
          })
          .elseWhileWithEnv(
            (maxRetries, errors) => attempts < maxRetries,
          )
          .run(5, onThen: (val) => value = val);

      expect(value, 3);
    });

    test('passes through value path', () {
      bool called = false;
      int? value;

      Cont.of<String, int>(42)
          .elseWhileWithEnv((env, errors) {
            called = true;
            return true;
          })
          .run('hello', onThen: (val) => value = val);

      expect(called, false);
      expect(value, 42);
    });

    test('supports multiple runs with different envs', () {
      int attempts = 0;

      final cont =
          Cont.fromDeferred<int, int>(() {
            attempts++;
            if (attempts < 5) {
              return Cont.stop<int, int>([
                ContError.capture('error'),
              ]);
            }
            return Cont.of(attempts);
          }).elseWhileWithEnv(
            (maxRetries, _) => attempts < maxRetries,
          );

      // First run with max 3 retries - will stop with errors
      List<ContError>? errors;
      cont.run(3, onElse: (e) => errors = e);
      expect(attempts, 3);
      expect(errors, isNotNull);

      // Reset and try with higher limit
      attempts = 0;
      int? value;
      cont.run(10, onThen: (val) => value = val);
      expect(value, 5);
    });
  });

  group('Cont.elseWhileWithEnv0', () {
    test('provides only env to predicate', () {
      String? receivedEnv;

      Cont.stop<String, int>([ContError.capture('err')])
          .elseWhileWithEnv0((env) {
            receivedEnv = env;
            return false;
          })
          .run('hello', onElse: (_) {});

      expect(receivedEnv, 'hello');
    });

    test(
      'behaves like elseWhileWithEnv with ignored errors',
      () {
        int attempts1 = 0;
        int attempts2 = 0;

        Cont.fromDeferred<String, int>(() {
              attempts1++;
              if (attempts1 < 3) {
                return Cont.stop<String, int>([
                  ContError.capture('error'),
                ]);
              }
              return Cont.of(attempts1);
            })
            .elseWhileWithEnv0((_) => true)
            .run('hello', onThen: (_) {});

        Cont.fromDeferred<String, int>(() {
              attempts2++;
              if (attempts2 < 3) {
                return Cont.stop<String, int>([
                  ContError.capture('error'),
                ]);
              }
              return Cont.of(attempts2);
            })
            .elseWhileWithEnv((_, __) => true)
            .run('hello', onThen: (_) {});

        expect(attempts1, attempts2);
      },
    );

    test('passes through value path', () {
      bool called = false;

      Cont.of<String, int>(42)
          .elseWhileWithEnv0((env) {
            called = true;
            return true;
          })
          .run('hello', onThen: (_) {});

      expect(called, false);
    });
  });
}
