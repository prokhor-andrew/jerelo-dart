import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.elseFork', () {
    test('propagates original termination', () {
      List<ContError>? errors;

      Cont.stop<(), int>([ContError.capture('original')])
          .elseFork((e) => Cont.of(()))
          .run((), onElse: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'original');
    });

    test('executes side effect without waiting', () {
      final order = <String>[];
      List<ContError>? errors;

      final List<void Function()> buffer = [];
      void flush() {
        for (final fn in buffer) {
          fn();
        }
        buffer.clear();
      }

      Cont.stop<(), int>([ContError.capture('err')])
          .elseFork((e) {
            return Cont.fromRun<(), ()>((
              runtime,
              observer,
            ) {
              buffer.add(() {
                order.add('fork');
                observer.onThen(());
              });
            });
          })
          .run(
            (),
            onElse: (e) {
              order.add('main');
              errors = e;
            },
          );

      expect(order, ['main']); // main completes first
      expect(errors![0].error, 'err');

      flush();
      expect(order, [
        'main',
        'fork',
      ]); // fork executes later
    });

    test('ignores side effect errors', () {
      List<ContError>? errors;
      final List<void Function()> buffer = [];
      void flush() {
        for (final fn in buffer) {
          fn();
        }
        buffer.clear();
      }

      Cont.stop<(), int>([ContError.capture('original')])
          .elseFork((e) {
            return Cont.fromRun<(), ()>((
              runtime,
              observer,
            ) {
              buffer.add(() {
                observer.onElse([
                  ContError.capture('fork error'),
                ]);
              });
            });
          })
          .run((), onElse: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'original');

      flush(); // fork executes but error is ignored
      expect(errors!.length, 1);
      expect(errors![0].error, 'original');
    });

    test('never executes on value path', () {
      bool forkCalled = false;
      int? value;

      Cont.of<(), int>(42)
          .elseFork((errors) {
            forkCalled = true;
            return Cont.of(());
          })
          .run((), onThen: (val) => value = val);

      expect(forkCalled, false);
      expect(value, 42);
    });

    test('terminates when fork builder throws', () {
      final cont = Cont.stop<(), int>().elseFork((errors) {
        throw 'Fork Builder Error';
      });

      ContError? error;
      cont.run(
        (),
        onElse: (errors) => error = errors.first,
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

      final cont = Cont.stop<(), int>().elseFork((errors) {
        return Cont.fromRun<(), ()>((runtime, observer) {
          buffer.add(() {
            forkCount++;
            observer.onThen(());
          });
        });
      });

      cont.run((), onElse: (_) {});
      expect(forkCount, 0);
      flush();
      expect(forkCount, 1);

      cont.run((), onElse: (_) {});
      expect(forkCount, 1);
      flush();
      expect(forkCount, 2);
    });

    test('supports empty error list', () {
      var forkCalled = false;
      final List<void Function()> buffer = [];
      void flush() {
        for (final fn in buffer) {
          fn();
        }
        buffer.clear();
      }

      Cont.stop<(), int>([])
          .elseFork((errors) {
            return Cont.fromRun<(), ()>((
              runtime,
              observer,
            ) {
              buffer.add(() {
                forkCalled = true;
                observer.onThen(());
              });
            });
          })
          .run((), onElse: (_) {});

      expect(forkCalled, false);
      flush();
      expect(forkCalled, true);
    });

    test('never calls onPanic on value path', () {
      Cont.of<(), int>(42)
          .elseFork((errors) => Cont.of(()))
          .run(
            (),
            onPanic: (_) => fail('Should not be called'),
            onThen: (_) {},
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
              observer.onElse([ContError.capture('error')]);
            });
          }).elseFork((errors) {
            forkCalled = true;
            return Cont.of(());
          });

      final token = cont.run((), onElse: (_) {});

      token.cancel();
      flush();

      expect(forkCalled, false);
    });

    test('provides defensive copy of errors', () {
      final originalErrors = [ContError.capture('err1')];
      List<ContError>? receivedErrors;

      Cont.stop<(), int>(originalErrors)
          .elseFork((errors) {
            receivedErrors = errors;
            errors.add(ContError.capture('err2'));
            return Cont.of(());
          })
          .run((), onElse: (_) {});

      expect(originalErrors.length, 1);
      expect(receivedErrors!.length, 2);
    });

    test('elseFork0 ignores error list', () {
      var fork1Called = false;
      var fork2Called = false;

      final List<void Function()> buffer = [];
      void flush() {
        for (final fn in buffer) {
          fn();
        }
        buffer.clear();
      }

      final cont1 = Cont.stop<(), int>().elseFork0(() {
        return Cont.fromRun<(), ()>((runtime, observer) {
          buffer.add(() {
            fork1Called = true;
            observer.onThen(());
          });
        });
      });

      final cont2 = Cont.stop<(), int>().elseFork((_) {
        return Cont.fromRun<(), ()>((runtime, observer) {
          buffer.add(() {
            fork2Called = true;
            observer.onThen(());
          });
        });
      });

      cont1.run((), onElse: (_) {});
      cont2.run((), onElse: (_) {});

      expect(fork1Called, false);
      expect(fork2Called, false);

      flush();
      expect(fork1Called, true);
      expect(fork2Called, true);
    });
  });
}
