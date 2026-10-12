import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.thenUntil', () {
    test('loops until predicate returns true', () {
      int counter = 0;
      int? value;

      Cont.fromDeferred<(), int>(() {
            counter++;
            return Cont.of(counter);
          })
          .thenUntil((n) => n == 5)
          .run((), onThen: (val) => value = val);

      expect(value, 5);
      expect(counter, 5);
    });

    test(
      'succeeds with first value when predicate is true',
      () {
        int? value;

        Cont.of<(), int>(42)
            .thenUntil((n) => true)
            .run((), onThen: (val) => value = val);

        expect(value, 42);
      },
    );

    test('continues looping until predicate is true', () {
      int counter = 0;
      int? value;

      Cont.fromDeferred<(), int>(() {
            counter++;
            return Cont.of(counter);
          })
          .thenUntil((n) => n >= 3)
          .run((), onThen: (val) => value = val);

      expect(value, 3);
      expect(counter, 3);
    });

    test('works inversely to thenWhile', () {
      int counter1 = 0;
      int counter2 = 0;
      int? value1;
      int? value2;

      Cont.fromDeferred<(), int>(() {
            counter1++;
            return Cont.of(counter1);
          })
          .thenUntil((n) => n == 5)
          .run((), onThen: (val) => value1 = val);

      Cont.fromDeferred<(), int>(() {
            counter2++;
            return Cont.of(counter2);
          })
          .thenWhile((n) => n != 5)
          .run((), onThen: (val) => value2 = val);

      expect(value1, value2);
      expect(counter1, counter2);
    });

    test('terminates on continuation failure', () {
      List<ContError>? errors;
      int iterations = 0;

      Cont.fromDeferred<(), int>(() {
            iterations++;
            if (iterations == 3) {
              return Cont.stop<(), int>([
                ContError.capture('manual error'),
              ]);
            }
            return Cont.of(iterations);
          })
          .thenUntil((n) => n == 10)
          .run((), onElse: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'manual error');
      expect(iterations, 3);
    });

    test('passes through original termination', () {
      List<ContError>? errors;
      bool predicateCalled = false;

      Cont.stop<(), int>([ContError.capture('err')])
          .thenUntil((n) {
            predicateCalled = true;
            return true;
          })
          .run((), onElse: (e) => errors = e);

      expect(predicateCalled, false);
      expect(errors!.length, 1);
      expect(errors![0].error, 'err');
    });

    test('terminates when predicate throws', () {
      int counter = 0;

      final cont =
          Cont.fromDeferred<(), int>(() {
            counter++;
            return Cont.of(counter);
          }).thenUntil((n) {
            if (n == 3) throw 'Predicate Error';
            return false;
          });

      ContError? error;
      cont.run(
        (),
        onElse: (errors) => error = errors.first,
      );

      expect(error!.error, 'Predicate Error');
      expect(counter, 3);
    });

    test('never calls onPanic', () {
      int counter = 0;

      Cont.fromDeferred<(), int>(() {
            counter++;
            return Cont.of(counter);
          })
          .thenUntil((n) => n == 3)
          .run(
            (),
            onPanic: (_) => fail('Should not be called'),
            onThen: (_) {},
          );

      expect(counter, 3);
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
          observer.onThen(iterations);
        });
      }).thenUntil((n) => n == 10);

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
      int counter = 0;
      final cont = Cont.fromDeferred<(), int>(() {
        counter++;
        return Cont.of(counter);
      }).thenUntil((n) => n == 3);

      int? value1;
      cont.run((), onThen: (val) => value1 = val);
      expect(value1, 3);
      expect(counter, 3);

      counter = 0;
      int? value2;
      cont.run((), onThen: (val) => value2 = val);
      expect(value2, 3);
      expect(counter, 3);
    });
  });

  group('Cont.thenUntil0', () {
    test(
      'loops until zero-argument predicate returns true',
      () {
        int counter = 0;
        int? value;

        Cont.fromDeferred<(), int>(() {
              counter++;
              return Cont.of(counter);
            })
            .thenUntil0(() => counter >= 4)
            .run((), onThen: (val) => value = val);

        expect(value, 4);
        expect(counter, 4);
      },
    );

    test('behaves like thenUntil with ignored value', () {
      int counter1 = 0;
      int counter2 = 0;

      Cont.fromDeferred<(), int>(() {
            counter1++;
            return Cont.of(counter1);
          })
          .thenUntil0(() => counter1 >= 3)
          .run((), onThen: (_) {});

      Cont.fromDeferred<(), int>(() {
            counter2++;
            return Cont.of(counter2);
          })
          .thenUntil((_) => counter2 >= 3)
          .run((), onThen: (_) {});

      expect(counter1, counter2);
    });

    test('stops when predicate returns true', () {
      int counter = 0;
      int? value;

      Cont.fromDeferred<(), int>(() {
            counter++;
            return Cont.of(counter);
          })
          .thenUntil0(() => true)
          .run((), onThen: (val) => value = val);

      expect(value, 1);
      expect(counter, 1);
    });

    test('passes through original termination', () {
      bool predicateCalled = false;
      List<ContError>? errors;

      Cont.stop<(), int>([ContError.capture('err')])
          .thenUntil0(() {
            predicateCalled = true;
            return true;
          })
          .run((), onElse: (e) => errors = e);

      expect(predicateCalled, false);
      expect(errors![0].error, 'err');
    });
  });

  group('Cont.thenUntilWithEnv', () {
    test('provides both env and value to predicate', () {
      String? receivedEnv;
      int? receivedValue;

      Cont.of<String, int>(42)
          .thenUntilWithEnv((env, n) {
            receivedEnv = env;
            receivedValue = n;
            return true; // stop immediately
          })
          .run('hello', onThen: (_) {});

      expect(receivedEnv, 'hello');
      expect(receivedValue, 42);
    });

    test('loops using env-based condition', () {
      int counter = 0;
      int? value;

      Cont.fromDeferred<int, int>(() {
            counter++;
            return Cont.of(counter);
          })
          .thenUntilWithEnv((maxCount, n) => n >= maxCount)
          .run(5, onThen: (val) => value = val);

      expect(value, 5);
      expect(counter, 5);
    });

    test('passes through error path', () {
      bool called = false;
      List<ContError>? errors;

      Cont.stop<String, int>([ContError.capture('err')])
          .thenUntilWithEnv((env, n) {
            called = true;
            return true;
          })
          .run('hello', onElse: (e) => errors = e);

      expect(called, false);
      expect(errors![0].error, 'err');
    });

    test('supports multiple runs with different envs', () {
      int counter = 0;

      final cont = Cont.fromDeferred<int, int>(() {
        counter++;
        return Cont.of(counter);
      }).thenUntilWithEnv((maxCount, n) => n >= maxCount);

      // First run with max 3
      int? value1;
      cont.run(3, onThen: (val) => value1 = val);
      expect(value1, 3);
      expect(counter, 3);

      // Second run with max 7
      counter = 0;
      int? value2;
      cont.run(7, onThen: (val) => value2 = val);
      expect(value2, 7);
      expect(counter, 7);
    });
  });

  group('Cont.thenUntilWithEnv0', () {
    test('provides only env to predicate', () {
      String? receivedEnv;

      Cont.of<String, int>(42)
          .thenUntilWithEnv0((env) {
            receivedEnv = env;
            return true;
          })
          .run('hello', onThen: (_) {});

      expect(receivedEnv, 'hello');
    });

    test(
      'behaves like thenUntilWithEnv with ignored value',
      () {
        int counter1 = 0;
        int counter2 = 0;

        Cont.fromDeferred<String, int>(() {
              counter1++;
              return Cont.of(counter1);
            })
            .thenUntilWithEnv0((_) => counter1 >= 3)
            .run('hello', onThen: (_) {});

        Cont.fromDeferred<String, int>(() {
              counter2++;
              return Cont.of(counter2);
            })
            .thenUntilWithEnv((_, __) => counter2 >= 3)
            .run('hello', onThen: (_) {});

        expect(counter1, counter2);
      },
    );

    test('passes through error path', () {
      bool called = false;

      Cont.stop<String, int>([ContError.capture('err')])
          .thenUntilWithEnv0((env) {
            called = true;
            return true;
          })
          .run('hello', onElse: (_) {});

      expect(called, false);
    });
  });
}
