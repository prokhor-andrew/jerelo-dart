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

    test('supports chaining as filters', () {
      int? value;

      Cont.of<(), int>(42)
          .when((n) => n > 0)
          .when((n) => n < 100)
          .when((n) => n.isEven)
          .run((), onValue: (val) => value = val);

      expect(value, 42);
    });

    test('terminates on first false predicate', () {
      int? value;

      Cont.of<(), int>(43)
          .when((n) => n > 0)
          .when((n) => n < 100)
          .when((n) => n.isEven) // fails here
          .run(
            (),
            onValue: (val) => value = val,
            onTerminate: (_) {},
          );

      expect(value, null);
    });

    test('supports null values', () {
      String? value;

      Cont.of<(), String?>(null)
          .when((val) => val == null)
          .run((), onValue: (val) => value = val);

      expect(value, null);
    });

    test('never calls onPanic', () {
      Cont.of<(), int>(42)
          .when((n) => n > 0)
          .run(
            (),
            onPanic: (_) => fail('Should not be called'),
            onValue: (_) {},
          );
    });

    test('works in conditional workflow', () {
      final results = <String>[];

      final processEven = (int n) => Cont.of<(), int>(n)
          .when((x) => x.isEven)
          .map((x) => 'even: $x')
          .elseDo((_) => Cont.of('not even'));

      processEven(
        4,
      ).run((), onValue: (v) => results.add(v));
      processEven(
        5,
      ).run((), onValue: (v) => results.add(v));

      expect(results, ['even: 4', 'not even']);
    });

    test(
      'complex predicate logic with multiple conditions',
      () {
        final results = <String>[];

        final process = (int n) => Cont.of<(), int>(n)
            .when((x) => x > 0 && x < 100 && x % 5 == 0)
            .map((x) => 'valid: $x')
            .elseDo((_) => Cont.of('invalid'));

        process(
          25,
        ).run((), onValue: (v) => results.add(v)); // valid
        process(-5).run(
          (),
          onValue: (v) => results.add(v),
        ); // invalid (< 0)
        process(150).run(
          (),
          onValue: (v) => results.add(v),
        ); // invalid (>= 100)
        process(23).run(
          (),
          onValue: (v) => results.add(v),
        ); // invalid (not % 5)

        expect(results, [
          'valid: 25',
          'invalid',
          'invalid',
          'invalid',
        ]);
      },
    );

    test('complex predicate with string validation', () {
      int? result;

      Cont.of<(), String>('hello@example.com')
          .when(
            (s) =>
                s.isNotEmpty &&
                s.contains('@') &&
                s.contains('.') &&
                s.length > 5,
          )
          .map((s) => s.length)
          .run((), onValue: (val) => result = val);

      expect(result, 17);
    });

    test('short-circuit evaluation test', () {
      final evaluations = <String>[];

      // First predicate fails, so second predicate should not execute
      bool predicate1(int n) {
        evaluations.add('pred1');
        return false;
      }

      bool predicate2(int n) {
        evaluations.add('pred2');
        return true;
      }

      int? value;
      Cont.of<(), int>(42)
          .when(predicate1)
          .when(
            predicate2,
          ) // This should never run because pred1 terminated
          .run(
            (),
            onValue: (val) => value = val,
            onTerminate: (_) {},
          );

      expect(value, null); // terminated
      expect(evaluations, [
        'pred1',
      ]); // pred2 never evaluated
    });

    test('short-circuit with early success', () {
      final evaluations = <String>[];

      Cont.of<(), int>(42)
          .when((n) {
            evaluations.add('check1');
            return n > 0;
          })
          .when((n) {
            evaluations.add('check2');
            return n < 100;
          })
          .when((n) {
            evaluations.add('check3');
            return n.isEven;
          })
          .run(
            (),
            onValue: (_) => evaluations.add('success'),
          );

      expect(evaluations, [
        'check1',
        'check2',
        'check3',
        'success',
      ]);
    });

    test('short-circuit on first false in chain', () {
      final evaluations = <String>[];

      Cont.of<(), int>(43) // odd number
          .when((n) {
            evaluations.add('check1: > 0');
            return n > 0;
          })
          .when((n) {
            evaluations.add('check2: < 100');
            return n < 100;
          })
          .when((n) {
            evaluations.add('check3: even');
            return n.isEven;
          })
          .when((n) {
            evaluations.add('check4: divisible by 5');
            return n % 5 == 0;
          })
          .run(
            (),
            onValue: (_) => evaluations.add('success'),
            onTerminate: (_) =>
                evaluations.add('terminated'),
          );

      // Stops at check3 (even check fails for 43)
      expect(evaluations, [
        'check1: > 0',
        'check2: < 100',
        'check3: even',
        'terminated',
      ]);
    });

    test('predicate with complex boolean logic', () {
      final results = <String>[];

      final validate = (int age, bool hasLicense) {
        return Cont.of<(), (int, bool)>((age, hasLicense))
            .when((record) {
              final (a, license) = record;
              return a >= 16 && a < 100 && license;
            })
            .map((_) => 'can drive')
            .elseDo((_) => Cont.of('cannot drive'));
      };

      validate(
        20,
        true,
      ).run((), onValue: (v) => results.add(v));
      validate(
        15,
        true,
      ).run((), onValue: (v) => results.add(v));
      validate(
        20,
        false,
      ).run((), onValue: (v) => results.add(v));
      validate(
        120,
        true,
      ).run((), onValue: (v) => results.add(v));

      expect(results, [
        'can drive',
        'cannot drive',
        'cannot drive',
        'cannot drive',
      ]);
    });

    test('nested when conditions', () {
      String? result;

      Cont.of<(), int>(42)
          .when((n) => n > 0)
          .thenDo(
            (n) =>
                Cont.of<(), int>(n * 2).when((x) => x > 50),
          )
          .map((n) => 'result: $n')
          .run((), onValue: (val) => result = val);

      expect(result, 'result: 84');
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

    test('stops when predicate is false', () {
      int? finalValue;
      int iterations = 0;

      Cont.fromDeferred<(), int>(() {
            iterations++;
            return Cont.of(iterations);
          })
          .asLongAs((n) {
            return n < 3;
          })
          .run((), onValue: (val) => finalValue = val);

      expect(finalValue, 3);
      expect(iterations, 3);
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
  });

  group('Cont.until', () {
    test('loops until predicate is true', () {
      int counter = 0;
      int? finalValue;

      Cont.fromDeferred<(), int>(() {
            counter++;
            return Cont.of(counter);
          })
          .until((n) => n >= 5)
          .run((), onValue: (val) => finalValue = val);

      expect(finalValue, 5);
      expect(counter, 5);
    });

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

    test(
      'returns first value when predicate immediately true',
      () {
        int? value;

        Cont.of<(), int>(42)
            .until((n) => true)
            .run((), onValue: (val) => value = val);

        expect(value, 42);
      },
    );

    test('terminates when predicate throws', () {
      final cont = Cont.of<(), int>(42).until((n) {
        throw 'Predicate Error';
      });

      ContError? error;
      cont.run(
        (),
        onTerminate: (errors) => error = errors.first,
      );

      expect(error!.error, 'Predicate Error');
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
      }).forever().trap((), onTerminate: (_) {});

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
