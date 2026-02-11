import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.thenFork', () {
    test('preserves original value', () {
      int? value;
      Cont.of<(), int>(42)
          .thenFork((a) => Cont.of('side effect'))
          .run((), onValue: (val) => value = val);

      expect(value, 42);
    });

    test('returns immediately without waiting', () {
      final order = <String>[];
      int? value;

      final List<void Function()> buffer = [];
      void flush() {
        for (final fn in buffer) {
          fn();
        }
        buffer.clear();
      }

      Cont.of<(), int>(10)
          .thenFork((a) {
            return Cont.fromRun<(), ()>((
              runtime,
              observer,
            ) {
              buffer.add(() {
                order.add('fork');
                observer.onValue(());
              });
            });
          })
          .run(
            (),
            onValue: (val) {
              order.add('main');
              value = val;
            },
          );

      expect(order, ['main']); // main completes first
      expect(value, 10);

      flush();
      expect(order, [
        'main',
        'fork',
      ]); // fork executes later
    });

    test('ignores side effect errors', () {
      int? value;
      final List<void Function()> buffer = [];
      void flush() {
        for (final fn in buffer) {
          fn();
        }
        buffer.clear();
      }

      Cont.of<(), int>(42)
          .thenFork((a) {
            return Cont.fromRun<(), ()>((
              runtime,
              observer,
            ) {
              buffer.add(() {
                observer.onTerminate([
                  ContError.capture('fork error'),
                ]);
              });
            });
          })
          .run((), onValue: (val) => value = val);

      expect(value, 42);
      flush(); // fork executes but error is ignored
      expect(value, 42);
    });

    test('passes through termination', () {
      final errors = [ContError.capture('err1')];
      List<ContError>? received;

      Cont.terminate<(), int>(errors)
          .thenFork((a) => Cont.of('side effect'))
          .run((), onTerminate: (e) => received = e);

      expect(received!.length, 1);
      expect(received![0].error, 'err1');
    });

    test('never executes on termination', () {
      bool forkCalled = false;
      Cont.terminate<(), int>()
          .thenFork((a) {
            forkCalled = true;
            return Cont.of(());
          })
          .run((), onTerminate: (_) {});

      expect(forkCalled, false);
    });

    test('terminates main when fork builder throws', () {
      final cont = Cont.of<(), int>(0).thenFork((val) {
        throw 'Fork Builder Error';
      });

      ContError? error;
      cont.run(
        (),
        onTerminate: (errors) => error = errors.first,
      );

      expect(error!.error, 'Fork Builder Error');
    });

    test('supports multiple runs', () {
      var forkCount = 0;
      final List<void Function()> buffer = [];
      void flush() {
        for (final fn in buffer) {
          fn();
        }
        buffer.clear();
      }

      final cont = Cont.of<(), int>(10).thenFork((a) {
        return Cont.fromRun<(), ()>((runtime, observer) {
          buffer.add(() {
            forkCount++;
            observer.onValue(());
          });
        });
      });

      cont.run(());
      expect(forkCount, 0);
      flush();
      expect(forkCount, 1);

      cont.run(());
      expect(forkCount, 1);
      flush();
      expect(forkCount, 2);
    });

    test('never calls onPanic for main path', () {
      Cont.of<(), int>(0)
          .thenFork((val) => Cont.of(()))
          .run(
            (),
            onPanic: (_) => fail('Should not be called'),
            onValue: (_) {},
          );
    });

    test('prevents fork execution after cancellation', () {
      bool forkCalled = false;

      final List<void Function()> buffer = [];
      void flush() {
        for (final fn in buffer) {
          fn();
        }
        buffer.clear();
      }

      final cont =
          Cont.fromRun<(), int>((runtime, observer) {
            buffer.add(() {
              if (runtime.isCancelled()) return;
              observer.onValue(10);
            });
          }).thenFork((val) {
            forkCalled = true;
            return Cont.of(());
          });

      int? value;
      final token = cont.run(
        (),
        onValue: (val) => value = val,
      );

      token.cancel();
      flush();

      expect(forkCalled, false);
      expect(value, null);
    });

    test('thenFork0 ignores input value', () {
      int? value1;
      int? value2;
      var fork1Called = false;
      var fork2Called = false;

      final List<void Function()> buffer = [];
      void flush() {
        for (final fn in buffer) {
          fn();
        }
        buffer.clear();
      }

      final cont1 = Cont.of<(), int>(10).thenFork0(() {
        return Cont.fromRun<(), ()>((runtime, observer) {
          buffer.add(() {
            fork1Called = true;
            observer.onValue(());
          });
        });
      });

      final cont2 = Cont.of<(), int>(10).thenFork((_) {
        return Cont.fromRun<(), ()>((runtime, observer) {
          buffer.add(() {
            fork2Called = true;
            observer.onValue(());
          });
        });
      });

      cont1.run((), onValue: (val) => value1 = val);
      cont2.run((), onValue: (val) => value2 = val);

      expect(value1, value2);
      expect(fork1Called, false);
      expect(fork2Called, false);

      flush();
      expect(fork1Called, true);
      expect(fork2Called, true);
    });
  });
}
