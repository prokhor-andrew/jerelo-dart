import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.flatten', () {
    test('flattens nested continuation', () {
      int? value;

      final nested = Cont.of<(), Cont<(), int>>(
        Cont.of(42),
      );

      nested.flatten().run(
        (),
        onValue: (val) => value = val,
      );

      expect(value, 42);
    });

    test('works equivalently to thenDo identity', () {
      int? value1;
      int? value2;

      final nested = Cont.of<(), Cont<(), int>>(
        Cont.of(100),
      );

      nested.flatten().run(
        (),
        onValue: (val) => value1 = val,
      );
      nested
          .thenDo((cont) => cont)
          .run((), onValue: (val) => value2 = val);

      expect(value1, value2);
      expect(value1, 100);
    });

    test('passes through inner termination', () {
      List<ContError>? errors;

      final nested = Cont.of<(), Cont<(), int>>(
        Cont.terminate<(), int>([
          ContError('inner error', StackTrace.current),
        ]),
      );

      nested.flatten().run(
        (),
        onTerminate: (e) => errors = e,
      );

      expect(errors!.length, 1);
      expect(errors![0].error, 'inner error');
    });

    test('passes through outer termination', () {
      List<ContError>? errors;

      final nested = Cont.terminate<(), Cont<(), int>>([
        ContError('outer error', StackTrace.current),
      ]);

      nested.flatten().run(
        (),
        onTerminate: (e) => errors = e,
      );

      expect(errors!.length, 1);
      expect(errors![0].error, 'outer error');
    });

    test('supports deferred inner continuation', () {
      var innerExecuted = false;
      int? value;

      final nested = Cont.of<(), Cont<(), int>>(
        Cont.fromDeferred(() {
          innerExecuted = true;
          return Cont.of(99);
        }),
      );

      expect(innerExecuted, false);
      nested.flatten().run(
        (),
        onValue: (val) => value = val,
      );
      expect(innerExecuted, true);
      expect(value, 99);
    });

    test('preserves environment', () {
      String? value;

      final nested = Cont.ask<String>().map(
        (env) => Cont.of<String, String>('env: $env'),
      );

      nested.flatten().run(
        'test',
        onValue: (val) => value = val,
      );

      expect(value, 'env: test');
    });

    test('supports chaining', () {
      int? value;

      final tripleNested =
          Cont.of<(), Cont<(), Cont<(), int>>>(
            Cont.of(Cont.of(42)),
          );

      tripleNested.flatten().flatten().run(
        (),
        onValue: (val) => value = val,
      );

      expect(value, 42);
    });

    test('supports multiple runs', () {
      var callCount = 0;
      final nested = Cont.of<(), Cont<(), int>>(
        Cont.fromRun((runtime, observer) {
          callCount++;
          observer.onValue(10);
        }),
      );

      int? value1;
      nested.flatten().run(
        (),
        onValue: (val) => value1 = val,
      );
      expect(value1, 10);
      expect(callCount, 1);

      int? value2;
      nested.flatten().run(
        (),
        onValue: (val) => value2 = val,
      );
      expect(value2, 10);
      expect(callCount, 2);
    });

    test('never calls onPanic', () {
      final nested = Cont.of<(), Cont<(), int>>(
        Cont.of(42),
      );

      nested.flatten().run(
        (),
        onPanic: (_) => fail('Should not be called'),
        onValue: (_) {},
      );
    });

    test('prevents inner execution after cancellation', () {
      bool innerExecuted = false;

      final List<void Function()> buffer = [];
      void flush() {
        for (final fn in buffer) {
          fn();
        }
        buffer.clear();
      }

      final nested = Cont.fromRun<(), Cont<(), int>>((
        runtime,
        observer,
      ) {
        buffer.add(() {
          if (runtime.isCancelled()) return;
          observer.onValue(
            Cont.fromRun((runtime, observer) {
              innerExecuted = true;
              observer.onValue(42);
            }),
          );
        });
      });

      int? value;
      final token = nested.flatten().run(
        (),
        onValue: (val) => value = val,
      );

      token.cancel();
      flush();

      expect(innerExecuted, false);
      expect(value, null);
    });

    test('creates nested structure with map', () {
      int? value;

      Cont.of<(), int>(5)
          .map((n) => Cont.of<(), int>(n * 2))
          .flatten()
          .run((), onValue: (val) => value = val);

      expect(value, 10);
    });

    test(
      'preserves monad law: flatten after of is identity',
      () {
        int? value1;
        int? value2;

        final cont = Cont.of<(), int>(42);

        cont.run((), onValue: (val) => value1 = val);
        Cont.of<(), Cont<(), int>>(
          cont,
        ).flatten().run((), onValue: (val) => value2 = val);

        expect(value1, value2);
      },
    );

    test('preserves monad law: associativity', () {
      int? value1;
      int? value2;

      final tripleNested =
          Cont.of<(), Cont<(), Cont<(), int>>>(
            Cont.of(Cont.of(42)),
          );

      tripleNested.flatten().flatten().run(
        (),
        onValue: (val) => value1 = val,
      );

      tripleNested
          .map((nested) => nested.flatten())
          .flatten()
          .run((), onValue: (val) => value2 = val);

      expect(value1, value2);
    });

    test('supports null values', () {
      String? value;

      final nested = Cont.of<(), Cont<(), String?>>(
        Cont.of(null),
      );

      nested.flatten().run(
        (),
        onValue: (val) => value = val,
      );

      expect(value, null);
    });

    test('deep nesting test (4 levels)', () {
      int? value;

      final deeplyNested =
          Cont.of<(), Cont<(), Cont<(), Cont<(), int>>>>(
            Cont.of(Cont.of(Cont.of(42))),
          );

      deeplyNested.flatten().flatten().flatten().run(
        (),
        onValue: (val) => value = val,
      );

      expect(value, 42);
    });

    test('deep nesting test (5 levels)', () {
      String? value;

      final level5 =
          Cont.of<
            (),
            Cont<(), Cont<(), Cont<(), Cont<(), String>>>>
          >(Cont.of(Cont.of(Cont.of(Cont.of('deep')))));

      level5.flatten().flatten().flatten().flatten().run(
        (),
        onValue: (val) => value = val,
      );

      expect(value, 'deep');
    });

    test('deep nesting with mixed operations', () {
      int? result;

      Cont.of<(), Cont<(), Cont<(), int>>>(
            Cont.of<(), Cont<(), int>>(Cont.of<(), int>(5)),
          )
          .flatten()
          .flatten()
          .map((n) => n * 2)
          .thenDo(
            (n) => Cont.of<(), Cont<(), int>>(
              Cont.of<(), int>(n + 10),
            ),
          )
          .flatten()
          .run((), onValue: (val) => result = val);

      expect(result, 20); // (5 * 2) + 10 = 20
    });

    test(
      'deep nesting with termination at various levels',
      () {
        // Termination at level 1 (outermost)
        List<ContError>? errors1;
        Cont.terminate<(), Cont<(), Cont<(), int>>>([
          ContError('level1', StackTrace.current),
        ]).flatten().flatten().run(
          (),
          onTerminate: (e) => errors1 = e,
        );

        expect(errors1!.length, 1);
        expect(errors1![0].error, 'level1');

        // Termination at level 2
        List<ContError>? errors2;
        Cont.of<(), Cont<(), Cont<(), int>>>(
          Cont.terminate<(), Cont<(), int>>([
            ContError('level2', StackTrace.current),
          ]),
        ).flatten().flatten().run(
          (),
          onTerminate: (e) => errors2 = e,
        );

        expect(errors2!.length, 1);
        expect(errors2![0].error, 'level2');

        // Termination at level 3 (innermost)
        List<ContError>? errors3;
        Cont.of<(), Cont<(), Cont<(), int>>>(
          Cont.of(
            Cont.terminate<(), int>([
              ContError('level3', StackTrace.current),
            ]),
          ),
        ).flatten().flatten().run(
          (),
          onTerminate: (e) => errors3 = e,
        );

        expect(errors3!.length, 1);
        expect(errors3![0].error, 'level3');
      },
    );

    test('deep nesting with deferred computations', () {
      final executionOrder = <int>[];
      int? result;

      // Build the nested structure: Cont<(), Cont<(), Cont<(), Cont<(), int>>>>
      final innermost = Cont.fromRun<(), int>((
        runtime,
        observer,
      ) {
        executionOrder.add(4);
        observer.onValue(100);
      });

      final level2 = Cont.fromRun<(), Cont<(), int>>((
        runtime,
        observer,
      ) {
        executionOrder.add(3);
        observer.onValue(innermost);
      });

      final level3 =
          Cont.fromRun<(), Cont<(), Cont<(), int>>>((
            runtime,
            observer,
          ) {
            executionOrder.add(2);
            observer.onValue(level2);
          });

      final level4 =
          Cont.fromRun<
            (),
            Cont<(), Cont<(), Cont<(), int>>>
          >((runtime, observer) {
            executionOrder.add(1);
            observer.onValue(level3);
          });

      level4.flatten().flatten().flatten().run(
        (),
        onValue: (val) => result = val,
      );

      expect(result, 100);
      expect(executionOrder, [1, 2, 3, 4]);
    });

    test('deep nesting preserves environment', () {
      String? result;

      final nested = Cont.ask<String>().map(
        (env) => Cont.ask<String>().map(
          (env2) => Cont.ask<String>().map(
            (env3) => '$env-$env2-$env3',
          ),
        ),
      );

      nested.flatten().flatten().run(
        'env',
        onValue: (val) => result = val,
      );

      expect(result, 'env-env-env');
    });
  });
}
