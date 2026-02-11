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
        onThen: (val) => value = val,
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
        onThen: (val) => value1 = val,
      );
      nested
          .thenDo((cont) => cont)
          .run((), onThen: (val) => value2 = val);

      expect(value1, value2);
      expect(value1, 100);
    });

    test('passes through inner termination', () {
      List<ContError>? errors;

      final nested = Cont.of<(), Cont<(), int>>(
        Cont.stop<(), int>([
          ContError.capture('inner error'),
        ]),
      );

      nested.flatten().run(
        (),
        onElse: (e) => errors = e,
      );

      expect(errors!.length, 1);
      expect(errors![0].error, 'inner error');
    });

    test('passes through outer termination', () {
      List<ContError>? errors;

      final nested = Cont.stop<(), Cont<(), int>>([
        ContError.capture('outer error'),
      ]);

      nested.flatten().run(
        (),
        onElse: (e) => errors = e,
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
        onThen: (val) => value = val,
      );
      expect(innerExecuted, true);
      expect(value, 99);
    });

    test('preserves environment', () {
      String? value;

      final nested = Cont.ask<String>().thenMap(
        (env) => Cont.of<String, String>('env: $env'),
      );

      nested.flatten().run(
        'test',
        onThen: (val) => value = val,
      );

      expect(value, 'env: test');
    });

    test('supports multiple runs', () {
      var callCount = 0;
      final nested = Cont.of<(), Cont<(), int>>(
        Cont.fromRun((runtime, observer) {
          callCount++;
          observer.onThen(10);
        }),
      );

      int? value1;
      nested.flatten().run(
        (),
        onThen: (val) => value1 = val,
      );
      expect(value1, 10);
      expect(callCount, 1);

      int? value2;
      nested.flatten().run(
        (),
        onThen: (val) => value2 = val,
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
        onThen: (_) {},
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
          observer.onThen(
            Cont.fromRun((runtime, observer) {
              innerExecuted = true;
              observer.onThen(42);
            }),
          );
        });
      });

      int? value;
      final token = nested.flatten().run(
        (),
        onThen: (val) => value = val,
      );

      token.cancel();
      flush();

      expect(innerExecuted, false);
      expect(value, null);
    });

    test('creates nested structure with map', () {
      int? value;

      Cont.of<(), int>(5)
          .thenMap((n) => Cont.of<(), int>(n * 2))
          .flatten()
          .run((), onThen: (val) => value = val);

      expect(value, 10);
    });

    test(
      'preserves monad law: flatten after of is identity',
      () {
        int? value1;
        int? value2;

        final cont = Cont.of<(), int>(42);

        cont.run((), onThen: (val) => value1 = val);
        Cont.of<(), Cont<(), int>>(
          cont,
        ).flatten().run((), onThen: (val) => value2 = val);

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
        onThen: (val) => value1 = val,
      );

      tripleNested
          .thenMap((nested) => nested.flatten())
          .flatten()
          .run((), onThen: (val) => value2 = val);

      expect(value1, value2);
    });
  });
}
