import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont<E, Never>.trap', () {
    test('executes with only termination handler', () {
      List<ContError>? errors;

      Cont.terminate<(), Never>([
        ContError.capture('err'),
      ]).trap((), onTerminate: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'err');
    });

    test('supports empty errors', () {
      List<ContError>? errors;

      Cont.terminate<(), Never>().trap(
        (),
        onTerminate: (e) => errors = e,
      );

      expect(errors, isEmpty);
    });

    test('never calls onPanic on termination', () {
      Cont.terminate<(), Never>([
        ContError.capture('err'),
      ]).trap(
        (),
        onPanic: (_) => fail('Should not be called'),
        onTerminate: (_) {},
      );
    });

    test('works with forever continuation', () {
      List<ContError>? errors;
      int iterations = 0;

      Cont.fromDeferred<(), int>(() {
        iterations++;
        if (iterations == 3) {
          return Cont.terminate<(), int>([
            ContError.capture('stop'),
          ]);
        }
        return Cont.of(iterations);
      }).forever().trap((), onTerminate: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'stop');
      expect(iterations, 3);
    });

    test('passes environment correctly', () {
      String? receivedEnv;

      Cont.fromRun<String, Never>((runtime, observer) {
        receivedEnv = runtime.env();
        observer.onTerminate([]);
      }).trap('test-env', onTerminate: (_) {});

      expect(receivedEnv, 'test-env');
    });

    test('supports multiple calls', () {
      var callCount = 0;

      final cont = Cont.terminate<(), Never>([
        ContError.capture('err'),
      ]);

      cont.trap((), onTerminate: (_) => callCount++);
      expect(callCount, 1);

      cont.trap((), onTerminate: (_) => callCount++);
      expect(callCount, 2);
    });

    test('stops execution after cancellation', () {
      bool terminated = false;

      final List<void Function()> buffer = [];
      void flush() {
        for (final fn in buffer) {
          fn();
        }
        buffer.clear();
      }

      final cont = Cont.fromRun<(), Never>((
        runtime,
        observer,
      ) {
        buffer.add(() {
          if (runtime.isCancelled()) return;
          terminated = true;
          observer.onTerminate([]);
        });
      });

      final token = cont.run((), onTerminate: (_) {});
      token.cancel();
      flush();

      expect(terminated, false);
    });

    test('triggers onPanic when onTerminate throws', () {
      ContError? panic;

      Cont.terminate<(), Never>([
        ContError.capture('err'),
      ]).trap(
        (),
        onPanic: (error) => panic = error,
        onTerminate: (errors) {
          throw 'terminate callback error';
        },
      );

      expect(panic!.error, 'terminate callback error');
    });
  });

  group('Cont<E, Never>.absurd', () {
    test('transforms Never to any type', () {
      final cont = Cont.terminate<(), Never>()
          .absurd<int>();

      expect(cont, isA<Cont<Object?, int>>());
    });

    test('preserves termination', () {
      List<ContError>? errors;

      Cont.terminate<(), Never>([ContError.capture('err')])
          .absurd<String>()
          .run((), onTerminate: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'err');
    });

    test('never produces value', () {
      Cont.terminate<(), Never>([
        ContError.capture('err'),
      ]).absurd<int>().run(
        (),
        onValue: (_) => fail('Should never be called'),
        onTerminate: (_) {},
      );
    });

    test('transforms to different types', () {
      final cont = Cont.terminate<(), Never>();

      final asInt = cont.absurd<int>();
      final asString = cont.absurd<String>();
      final asList = cont.absurd<List<double>>();

      expect(asInt, isA<Cont<Object?, int>>());
      expect(asString, isA<Cont<Object?, String>>());
      expect(asList, isA<Cont<Object?, List<double>>>());
    });

    test('works with forever', () {
      int iterations = 0;
      List<ContError>? errors;

      Cont.fromDeferred<(), int>(() {
        iterations++;
        if (iterations == 5) {
          return Cont.terminate<(), int>([
            ContError.capture('stop'),
          ]);
        }
        return Cont.of(iterations);
      }).forever().absurd<String>().run(
        (),
        onTerminate: (e) => errors = e,
      );

      expect(errors!.length, 1);
      expect(errors![0].error, 'stop');
      expect(iterations, 5);
    });

    test('preserves environment', () {
      String? receivedEnv;

      Cont.fromRun<String, Never>((runtime, observer) {
        receivedEnv = runtime.env();
        observer.onTerminate([]);
      }).absurd<int>().run('test-env', onTerminate: (_) {});

      expect(receivedEnv, 'test-env');
    });

    test('supports multiple runs', () {
      var callCount = 0;

      final cont = Cont.terminate<(), Never>([
        ContError.capture('err'),
      ]).absurd<int>();

      cont.run((), onTerminate: (_) => callCount++);
      expect(callCount, 1);

      cont.run((), onTerminate: (_) => callCount++);
      expect(callCount, 2);
    });

    test('never calls onPanic', () {
      Cont.terminate<(), Never>([
        ContError.capture('err'),
      ]).absurd<int>().run(
        (),
        onPanic: (_) => fail('Should not be called'),
        onTerminate: (_) {},
      );
    });

    test('prevents execution after cancellation', () {
      bool executed = false;

      final List<void Function()> buffer = [];
      void flush() {
        for (final fn in buffer) {
          fn();
        }
        buffer.clear();
      }

      final cont = Cont.fromRun<(), Never>((
        runtime,
        observer,
      ) {
        buffer.add(() {
          if (runtime.isCancelled()) return;
          executed = true;
          observer.onTerminate([]);
        });
      }).absurd<int>();

      final token = cont.run((), onTerminate: (_) {});
      token.cancel();
      flush();

      expect(executed, false);
    });

    test('provides type compatibility in composition', () {
      List<ContError>? errors;

      final neverCont = Cont.terminate<(), Never>([
        ContError.capture('never error'),
      ]);

      final intCont = Cont.of<(), int>(42);

      // Use absurd to make types compatible for elseDo
      intCont
          .thenDo((n) => neverCont.absurd<int>())
          .run((), onTerminate: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'never error');
    });

    test('supports chaining with map', () {
      List<ContError>? errors;

      Cont.terminate<(), Never>([ContError.capture('err')])
          .absurd<int>()
          .map((n) => n * 2)
          .run(
            (),
            onValue: (_) => fail('Should not be called'),
            onTerminate: (e) => errors = e,
          );

      expect(errors!.length, 1);
      expect(errors![0].error, 'err');
    });

    test('enables type unification', () {
      final result = <int?>[];

      final cont1 = Cont.of<(), int>(42);
      final cont2 = Cont.terminate<(), Never>()
          .absurd<int>();

      cont1.run((), onValue: (v) => result.add(v));
      cont2.run(
        (),
        onValue: (v) => result.add(v),
        onTerminate: (_) => result.add(null),
      );

      expect(result, [42, null]);
    });
  });
}
