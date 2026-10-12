import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.elseUntil', () {
    test('retries until predicate returns true', () {
      int attempts = 0;
      List<ContError>? errors;

      Cont.fromDeferred<(), int>(() {
            attempts++;
            return Cont.stop<(), int>([
              ContError.capture('error $attempts'),
            ]);
          })
          .elseUntil(
            (errors) => errors.first.error == 'error 3',
          )
          .run((), onElse: (e) => errors = e);

      expect(attempts, 3);
      expect(errors![0].error, 'error 3');
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
          .elseUntil((_) => false)
          .run((), onThen: (val) => value = val);

      expect(value, 42);
      expect(attempts, 4);
    });

    test(
      'stops immediately when predicate returns true',
      () {
        int attempts = 0;
        List<ContError>? errors;

        Cont.fromDeferred<(), int>(() {
              attempts++;
              return Cont.stop<(), int>([
                ContError.capture('error'),
              ]);
            })
            .elseUntil((_) => true)
            .run((), onElse: (e) => errors = e);

        expect(attempts, 1);
        expect(errors![0].error, 'error');
      },
    );

    test('works inversely to elseWhile', () {
      int attempts1 = 0;
      int attempts2 = 0;
      List<ContError>? errors1;
      List<ContError>? errors2;

      Cont.fromDeferred<(), int>(() {
            attempts1++;
            return Cont.stop<(), int>([
              ContError.capture('error $attempts1'),
            ]);
          })
          .elseUntil(
            (errors) => errors.first.error == 'error 3',
          )
          .run((), onElse: (e) => errors1 = e);

      Cont.fromDeferred<(), int>(() {
            attempts2++;
            return Cont.stop<(), int>([
              ContError.capture('error $attempts2'),
            ]);
          })
          .elseWhile(
            (errors) => errors.first.error != 'error 3',
          )
          .run((), onElse: (e) => errors2 = e);

      expect(attempts1, attempts2);
      expect(errors1![0].error, errors2![0].error);
    });

    test(
      'passes through value without executing predicate',
      () {
        bool predicateCalled = false;
        int? value;

        Cont.of<(), int>(42)
            .elseUntil((errors) {
              predicateCalled = true;
              return false;
            })
            .run((), onThen: (val) => value = val);

        expect(predicateCalled, false);
        expect(value, 42);
      },
    );

    test('terminates when predicate throws', () {
      ContError? error;

      Cont.stop<(), int>([ContError.capture('err')])
          .elseUntil((errors) {
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
          .elseUntil((_) => false)
          .run(
            (),
            onPanic: (_) => fail('Should not be called'),
            onThen: (_) {},
          );

      expect(attempts, 3);
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
      }).elseUntil((_) => false);

      cont.run((), onThen: (_) {}, onElse: (_) {});

      flush(); // iteration 1
      expect(iterations, 1);

      flush(); // iteration 2
      expect(iterations, 2);

      cancelled = true;
      flush(); // cancelled, terminates
      expect(iterations, 2);
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
      }).elseUntil((_) => false);

      int? value1;
      cont.run((), onThen: (val) => value1 = val);
      expect(value1, 3);

      attempts = 0;
      int? value2;
      cont.run((), onThen: (val) => value2 = val);
      expect(value2, 3);
    });
  });

  group('Cont.elseUntil0', () {
    test(
      'retries until zero-argument predicate returns true',
      () {
        int attempts = 0;
        List<ContError>? errors;

        Cont.fromDeferred<(), int>(() {
              attempts++;
              return Cont.stop<(), int>([
                ContError.capture('error'),
              ]);
            })
            .elseUntil0(() => attempts >= 3)
            .run((), onElse: (e) => errors = e);

        expect(attempts, 3);
        expect(errors, isNotNull);
      },
    );

    test('behaves like elseUntil with ignored errors', () {
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
      }).elseUntil0(() => false).run((), onThen: (_) {});

      Cont.fromDeferred<(), int>(() {
        attempts2++;
        if (attempts2 < 3) {
          return Cont.stop<(), int>([
            ContError.capture('error'),
          ]);
        }
        return Cont.of(attempts2);
      }).elseUntil((_) => false).run((), onThen: (_) {});

      expect(attempts1, attempts2);
    });

    test('stops immediately when predicate is true', () {
      int attempts = 0;
      List<ContError>? errors;

      Cont.fromDeferred<(), int>(() {
            attempts++;
            return Cont.stop<(), int>([
              ContError.capture('error'),
            ]);
          })
          .elseUntil0(() => true)
          .run((), onElse: (e) => errors = e);

      expect(attempts, 1);
      expect(errors![0].error, 'error');
    });
  });

  group('Cont.elseUntilWithEnv', () {
    test('provides both env and errors to predicate', () {
      String? receivedEnv;
      List<ContError>? receivedErrors;

      Cont.stop<String, int>([ContError.capture('err')])
          .elseUntilWithEnv((env, errors) {
            receivedEnv = env;
            receivedErrors = errors;
            return true; // stop immediately
          })
          .run('hello', onElse: (_) {});

      expect(receivedEnv, 'hello');
      expect(receivedErrors!.length, 1);
      expect(receivedErrors![0].error, 'err');
    });

    test('retries using env-based condition', () {
      int attempts = 0;
      List<ContError>? errors;

      Cont.fromDeferred<int, int>(() {
            attempts++;
            return Cont.stop<int, int>([
              ContError.capture('error $attempts'),
            ]);
          })
          .elseUntilWithEnv(
            (maxRetries, errors) => attempts >= maxRetries,
          )
          .run(3, onElse: (e) => errors = e);

      expect(attempts, 3);
      expect(errors![0].error, 'error 3');
    });
  });

  group('Cont.elseUntilWithEnv0', () {
    test('provides only env to predicate', () {
      String? receivedEnv;

      Cont.stop<String, int>([ContError.capture('err')])
          .elseUntilWithEnv0((env) {
            receivedEnv = env;
            return true;
          })
          .run('hello', onElse: (_) {});

      expect(receivedEnv, 'hello');
    });

    test(
      'behaves like elseUntilWithEnv with ignored errors',
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
            .elseUntilWithEnv0((_) => false)
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
            .elseUntilWithEnv((_, __) => false)
            .run('hello', onThen: (_) {});

        expect(attempts1, attempts2);
      },
    );
  });
}
