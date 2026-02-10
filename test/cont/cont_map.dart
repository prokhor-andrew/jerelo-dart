import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.map', () {
    test('executes on value channel', () {
      final cont = Cont.of<(), int>(
        0,
      ).map((val) => val + 5);

      int? value = null;

      expect(value, null);
      cont.run((), onValue: (val) => value = val);

      expect(value, 5);
    });

    test('terminates when function throws', () {
      final cont = Cont.of<(), int>(0).map((val) {
        throw 'Thrown Error';
      });

      ContError? error = null;

      expect(error, null);
      cont.run(
        (),
        onTerminate: (errors) => error = errors.first,
      );

      expect(error!.error, 'Thrown Error');
    });

    test('preserves functor identity law', () {
      A id<A>(A a) => a;

      final cont1 = Cont.of<(), int>(0);

      final cont2 = cont1.map(id);

      int? value1 = null;
      int? value2 = null;

      expect(value1, null);
      cont1.run((), onValue: (val1) => value1 = val1);

      expect(value2, null);
      cont2.run((), onValue: (val2) => value2 = val2);

      expect(value1, value2);
    });

    test('never calls map function on termination', () {
      bool called = false;
      final cont = Cont.terminate<(), int>().map((val) {
        called = true;
        return val + 5;
      });

      cont.run((), onTerminate: (_) {});

      expect(called, false);
    });

    test('passes through termination', () {
      final errors = [
        ContError('err1', StackTrace.current),
        ContError('err2', StackTrace.current),
      ];
      final cont = Cont.terminate<(), int>(
        errors,
      ).map((val) => val + 5);

      List<ContError>? received;

      cont.run((), onTerminate: (e) => received = e);

      expect(received!.length, 2);
      expect(received![0].error, 'err1');
      expect(received![1].error, 'err2');
    });

    test('never calls onValue on termination', () {
      final cont = Cont.terminate<(), int>().map(
        (val) => val + 5,
      );

      cont.run(
        (),
        onTerminate: (_) {},
        onValue: (_) {
          fail('Should not be called');
        },
      );
    });

    test('transforms value type', () {
      final cont = Cont.of<(), int>(
        42,
      ).map((val) => 'value: $val');

      String? value;
      cont.run((), onValue: (val) => value = val);

      expect(value, 'value: 42');
    });

    test('supports multiple runs', () {
      final cont = Cont.of<(), int>(
        10,
      ).map((val) => val * 3);

      int? value1;
      cont.run((), onValue: (val) => value1 = val);
      expect(value1, 30);

      int? value2;
      cont.run((), onValue: (val) => value2 = val);
      expect(value2, 30);
    });

    test('supports null values', () {
      String? value = 'initial';
      final cont = Cont.of<(), String?>(
        null,
      ).map((val) => val);

      cont.run((), onValue: (val) => value = val);

      expect(value, null);
    });

    test('never calls onPanic', () {
      final cont = Cont.of<(), int>(
        0,
      ).map((val) => val + 5);

      cont.run(
        (),
        onPanic: (_) {
          fail('Should not be called');
        },
        onValue: (_) {},
      );
    });

    test('prevents map execution after cancellation', () {
      bool mapCalled = false;

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
          }).map((val) {
            mapCalled = true;
            return val + 5;
          });

      int? value;
      final token = cont.run(
        (),
        onValue: (val) => value = val,
      );

      token.cancel();
      flush();

      expect(mapCalled, false);
      expect(value, null);
    });

    test('preserves stack trace when throwing', () {
      final cont = Cont.of<(), int>(0).map((val) {
        throw 'Test Error';
      });

      ContError? error;
      cont.run(
        (),
        onTerminate: (errors) => error = errors.first,
      );

      expect(error!.error, 'Test Error');
      expect(error!.stackTrace, isNotNull);
    });

    test('preserves functor composition law', () {
      C Function(A) compose<A, B, C>(
        B Function(A) lf,
        C Function(B) rf,
      ) {
        return (a) {
          return rf(lf(a));
        };
      }

      int add5(int a) => a + 5;
      int mul2(int a) => a * 2;

      final cont1 = Cont.of<(), int>(10);

      final cont2 = cont1.map(add5).map(mul2);

      final cont3 = cont1.map(compose(add5, mul2));

      int? value2 = null;
      int? value3 = null;

      expect(value2, null);
      cont2.run((), onValue: (val2) => value2 = val2);
      expect(value3, null);
      cont3.run((), onValue: (val3) => value3 = val3);

      expect(value2, value3);
    });

    test('map((_) => 20) ≡ map0(() => 20) ≡ as(20)', () {
      final cont1 = Cont.of<(), int>(10).map((_) => 20);
      final cont2 = Cont.of<(), int>(10).map0(() => 20);
      final cont3 = Cont.of<(), int>(10).as(20);

      int? value1;
      int? value2;
      int? value3;
      cont1.run((), onValue: (val) => value1 = val);
      cont2.run((), onValue: (val) => value2 = val);
      cont3.run((), onValue: (val) => value3 = val);

      expect(value1, 20);
      expect(value2, 20);
      expect(value3, 20);
    });

    test('chaining map multiple times (composition)', () {
      String? result;

      Cont.of<(), int>(10)
          .map((n) => n + 5) // 15
          .map((n) => n * 2) // 30
          .map((n) => n - 10) // 20
          .map((n) => 'result: $n') // 'result: 20'
          .run((), onValue: (val) => result = val);

      expect(result, 'result: 20');
    });

    test('long chain of map operations', () {
      int? result;

      Cont.of<(), int>(1)
          .map((n) => n + 1) // 2
          .map((n) => n * 2) // 4
          .map((n) => n + 3) // 7
          .map((n) => n * 10) // 70
          .map((n) => n - 20) // 50
          .run((), onValue: (val) => result = val);

      expect(result, 50);
    });

    test('map chain with type transformations', () {
      String? result;

      Cont.of<(), int>(42)
          .map((n) => n.toString()) // '42'
          .map((s) => s.length) // 2
          .map((len) => len * 10) // 20
          .map((n) => 'final: $n') // 'final: 20'
          .run((), onValue: (val) => result = val);

      expect(result, 'final: 20');
    });
  });
}
