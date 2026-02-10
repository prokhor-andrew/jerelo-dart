import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.fromDeferred', () {
    test('executes successfully', () {
      var isRun = false;
      final cont = Cont.fromDeferred<(), ()>(() {
        isRun = true;
        return Cont.of(());
      });

      expect(isRun, false);
      cont.run(());
      expect(isRun, true);
    });

    test('delivers value through onValue channel', () {
      var value = 0;
      final cont = Cont.fromDeferred<(), int>(() {
        return Cont.of(15);
      });

      expect(value, 0);
      cont.run((), onValue: (v) => value = v);
      expect(value, 15);
    });

    test('delivers termination errors', () {
      List<ContError>? errors;
      final cont = Cont.fromDeferred<(), int>(() {
        return Cont.terminate([
          ContError("deferred error", StackTrace.current),
        ]);
      });

      expect(errors, null);
      cont.run((), onTerminate: (e) => errors = e);
      expect(errors![0].error, "deferred error");
    });

    test('delivers empty termination', () {
      List<ContError>? errors;
      final cont = Cont.fromDeferred<(), int>(() {
        return Cont.terminate();
      });

      expect(errors, null);
      cont.run((), onTerminate: (e) => errors = e);
      expect(errors, []);
    });

    test('terminates when thunk throws', () {
      List<ContError>? errors;
      final cont = Cont.fromDeferred<(), int>(() {
        throw "thunk error";
      });

      expect(errors, null);
      cont.run((), onTerminate: (e) => errors = e);
      expect(errors![0].error, "thunk error");
    });

    test('passes environment correctly', () {
      var envValue = 0;
      final cont = Cont.fromDeferred<int, ()>(() {
        return Cont.fromRun((runtime, observer) {
          envValue = runtime.env();
          observer.onValue(());
        });
      });

      expect(envValue, 0);
      cont.run(42);
      expect(envValue, 42);
    });

    test('executes fresh thunk on each run', () {
      var callCount = 0;
      final cont = Cont.fromDeferred<(), int>(() {
        callCount += 1;
        return Cont.of(callCount);
      });

      var value1 = 0;
      var value2 = 0;

      cont.run((), onValue: (v) => value1 = v);
      cont.run((), onValue: (v) => value2 = v);

      expect(callCount, 2);
      expect(value1, 1);
      expect(value2, 2);
    });

    test('blocks inner onValue after cancellation', () {
      var value = 0;
      final List<void Function()> buffer = [];
      void flush() {
        for (final value in buffer) {
          value();
        }
        buffer.clear();
      }

      final cont = Cont.fromDeferred<(), int>(() {
        return Cont.fromRun((runtime, observer) {
          buffer.add(() {
            observer.onValue(10);
          });
        });
      });

      expect(value, 0);
      final token = cont.run(
        (),
        onValue: (val) => value = val,
      );
      expect(value, 0);
      token.cancel();
      flush();
      expect(value, 0);
    });

    test('blocks inner onTerminate after cancellation', () {
      List<ContError>? errors;
      final List<void Function()> buffer = [];
      void flush() {
        for (final value in buffer) {
          value();
        }
        buffer.clear();
      }

      final cont = Cont.fromDeferred<(), int>(() {
        return Cont.fromRun((runtime, observer) {
          buffer.add(() {
            observer.onTerminate([
              ContError("error", StackTrace.current),
            ]);
          });
        });
      });

      expect(errors, null);
      final token = cont.run(
        (),
        onTerminate: (e) => errors = e,
      );
      expect(errors, null);
      token.cancel();
      flush();
      expect(errors, null);
    });

    test('supports Cont<E, Never> inner continuation', () {
      List<ContError>? errors;
      final cont = Cont.fromDeferred<(), int>(() {
        return Cont.fromRun<(), Never>((runtime, observer) {
          observer.onTerminate([
            ContError("never error", StackTrace.current),
          ]);
        });
      });

      cont.run(
        (),
        onTerminate: (e) => errors = e,
        onValue: (v) {
          fail('Should not be called');
        },
      );

      expect(errors![0].error, "never error");
    });
  });
}
