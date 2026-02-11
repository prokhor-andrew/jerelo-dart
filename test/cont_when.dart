import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.when', () {
    test('succeeds when predicate is true', () {
      int? value;
      Cont.of<(), int>(42)
          .when((n) => n > 0)
          .run((), onValue: (val) => value = val);

      expect(value, 42);
    });

    test('terminates when predicate is false', () {
      List<ContError>? errors;
      int? value;

      Cont.of<(), int>(-5)
          .when((n) => n > 0)
          .run(
            (),
            onValue: (val) => value = val,
            onTerminate: (e) => errors = e,
          );

      expect(value, null);
      expect(errors, isNotNull);
      expect(errors, isEmpty); // terminates with no errors
    });

    test('passes through original termination', () {
      List<ContError>? errors;

      Cont.terminate<(), int>([ContError.capture('err')])
          .when((n) => n > 0)
          .run((), onTerminate: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'err');
    });

    test('terminates when predicate throws', () {
      final cont = Cont.of<(), int>(42).when((n) {
        throw 'Predicate Error';
      });

      ContError? error;
      cont.run(
        (),
        onTerminate: (errors) => error = errors.first,
      );

      expect(error!.error, 'Predicate Error');
    });

    test('never calls onPanic', () {
      Cont.of<(), int>(42)
          .when((n) => n > 0)
          .run(
            (),
            onPanic: (_) => fail('Should not be called'),
          );
    });

    test('works in conditional workflow', () {
      final results = <String>[];

      final processEven = (int n) => Cont.of<(), int>(n)
          .when((x) => x.isEven)
          .map((x) => 'even: $x')
          .recover((_) => 'not even');

      processEven(
        4,
      ).run((), onValue: (v) => results.add(v));
      processEven(
        5,
      ).run((), onValue: (v) => results.add(v));

      expect(results, ['even: 4', 'not even']);
    });
  });

  group('Cont.asLongAs', () {
    test('loops while predicate is true', () {
      final values = <int>[];
      int counter = 0;

      Cont.fromDeferred<(), int>(() {
            counter++;
            return Cont.of(counter);
          })
          .asLongAs((n) => n < 5)
          .run((), onValue: (val) => values.add(val));

      expect(values, [5]); // stops when counter reaches 5
      expect(counter, 5);
    });

    test(
      'returns first value when predicate immediately false',
      () {
        int? value;

        Cont.of<(), int>(42)
            .asLongAs((n) => false)
            .run((), onValue: (val) => value = val);

        expect(value, 42);
      },
    );

    test('terminates on continuation failure', () {
      List<ContError>? errors;
      int iterations = 0;

      Cont.fromDeferred<(), int>(() {
            iterations++;
            if (iterations == 3) {
              return Cont.terminate<(), int>([
                ContError.capture('loop error'),
              ]);
            }
            return Cont.of(iterations);
          })
          .asLongAs((n) => n < 10)
          .run((), onTerminate: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'loop error');
      expect(iterations, 3);
    });

    test('terminates when predicate throws', () {
      final cont = Cont.of<(), int>(42).asLongAs((n) {
        throw 'Predicate Error';
      });

      ContError? error;
      cont.run(
        (),
        onTerminate: (errors) => error = errors.first,
      );

      expect(error!.error, 'Predicate Error');
    });

    test('never triggers onPanic', () {
      int counter = 0;

      Cont.fromDeferred<(), int>(() {
            counter++;
            return Cont.of(counter);
          })
          .asLongAs((n) => n < 3)
          .run(
            (),
            onPanic: (_) => fail('Should not be called'),
            onValue: (_) {},
          );

      expect(counter, 3);
    });

    test('supports multiple runs', () {
      int counter = 0;
      final cont = Cont.fromDeferred<(), int>(() {
        counter++;
        return Cont.of(counter);
      }).asLongAs((n) => n < 3);

      int? value1;
      cont.run((), onValue: (val) => value1 = val);
      expect(value1, 3);
      expect(counter, 3);

      counter = 0;
      int? value2;
      cont.run((), onValue: (val) => value2 = val);
      expect(value2, 3);
      expect(counter, 3);
    });
  });

  group('Cont.until', () {
    test('works inversely to asLongAs', () {
      int counter1 = 0;
      int counter2 = 0;
      int? value1;
      int? value2;

      Cont.fromDeferred<(), int>(() {
            counter1++;
            return Cont.of(counter1);
          })
          .until((n) => n == 5)
          .run((), onValue: (val) => value1 = val);

      Cont.fromDeferred<(), int>(() {
            counter2++;
            return Cont.of(counter2);
          })
          .asLongAs((n) => n != 5)
          .run((), onValue: (val) => value2 = val);

      expect(value1, value2);
      expect(counter1, counter2);
    });

    test('never triggers onPanic', () {
      int counter = 0;

      Cont.fromDeferred<(), int>(() {
            counter++;
            return Cont.of(counter);
          })
          .until((n) => n == 3)
          .run(
            (),
            onPanic: (_) => fail('Should not be called'),
            onValue: (_) {},
          );

      expect(counter, 3);
    });

    test('stops when error thrown in predicate', () {
      int counter = 0;

      final cont = Cont.fromDeferred<(), int>(() {
        counter++;
        return Cont.of(counter);
      }).until((n) {
        if (n == 3) throw 'Predicate Error';
        return false;
      });

      ContError? error;
      cont.run(
        (),
        onTerminate: (errors) => error = errors.first,
      );

      expect(error!.error, 'Predicate Error');
      expect(counter, 3);
    });

    test('stops when error manually emitted', () {
      List<ContError>? errors;
      int iterations = 0;

      Cont.fromDeferred<(), int>(() {
            iterations++;
            if (iterations == 3) {
              return Cont.terminate<(), int>([
                ContError.capture('manual error'),
              ]);
            }
            return Cont.of(iterations);
          })
          .until((n) => n == 10)
          .run((), onTerminate: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'manual error');
      expect(iterations, 3);
    });

    test('supports multiple runs', () {
      int counter = 0;
      final cont = Cont.fromDeferred<(), int>(() {
        counter++;
        return Cont.of(counter);
      }).until((n) => n == 3);

      int? value1;
      cont.run((), onValue: (val) => value1 = val);
      expect(value1, 3);
      expect(counter, 3);

      counter = 0;
      int? value2;
      cont.run((), onValue: (val) => value2 = val);
      expect(value2, 3);
      expect(counter, 3);
    });
  });

  group('Cont.forever', () {
    test('has Never return type', () {
      final cont = Cont.of<(), int>(42).forever();

      // Type check: cont should be Cont<(), Never>
      expect(cont, isA<Cont<Object?, Never>>());
    });

    test('terminates on continuation failure', () {
      List<ContError>? errors;
      int iterations = 0;

      Cont.fromDeferred<(), int>(() {
        iterations++;
        if (iterations == 5) {
          return Cont.terminate<(), int>([
            ContError.capture('stop'),
          ]);
        }
        return Cont.of(iterations);
      }).forever().trap((), onTerminate: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'stop');
      expect(iterations, 5);
    });

    test('never calls onValue', () {
      int iterations = 0;

      Cont.fromDeferred<(), int>(() {
        iterations++;
        if (iterations == 3) {
          return Cont.terminate<(), int>();
        }
        return Cont.of(iterations);
      }).forever().trap(());

      expect(iterations, 3);
    });

    test('supports conversion with absurd', () {
      final cont = Cont.of<(), int>(
        42,
      ).forever().absurd<String>();

      expect(cont, isA<Cont<Object?, String>>());
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
            observer.onTerminate([]);
            return;
          }
          iterations++;
          observer.onValue(iterations);
        });
      }).forever();

      cont.trap((), onTerminate: (_) {});

      flush(); // iteration 1
      expect(iterations, 1);

      flush(); // iteration 2
      expect(iterations, 2);

      cancelled = true;
      flush(); // cancelled, terminates
      expect(iterations, 2);
    });
  });
}
