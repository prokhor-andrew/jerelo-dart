import 'dart:async';

import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.fromRun', () {
    test('supports ContObserver<Never>', () {
      final cont = Cont.fromRun<(), Never>((
        runtime,
        observer,
      ) {
        observer.onTerminate();
      });

      cont.run(
        (),
        onTerminate: (errors) {
          expect(errors, []);
        },
        onValue: (_) {
          fail('Should not be called');
        },
      );
    });

    test('executes when run is called', () {
      var isRun = false;
      final cont = Cont.fromRun<(), int>((
        runtime,
        observer,
      ) {
        isRun = true;
      });

      expect(isRun, false);
      cont.run(());
      expect(isRun, true);
    });

    test('delivers value through onValue channel', () {
      var value = 15;
      final cont = Cont.fromRun<(), int>((
        runtime,
        observer,
      ) {
        observer.onValue(0);
      });

      expect(value, 15);
      cont.run((), onValue: (v) => value = v);
      expect(value, 0);
    });

    test(
      'delivers empty termination when manually specified',
      () {
        List<ContError>? errors = null;
        final cont = Cont.fromRun<(), int>((
          runtime,
          observer,
        ) {
          observer.onTerminate([]);
        });

        expect(errors, null);
        cont.run((), onTerminate: (e) => errors = e);
        expect(errors, []);
      },
    );

    test(
      'delivers termination errors when manually specified',
      () {
        List<ContError>? errors = null;
        final cont = Cont.fromRun<(), int>((
          runtime,
          observer,
        ) {
          observer.onTerminate([
            ContError("random error", StackTrace.current),
          ]);
        });

        expect(errors, null);
        cont.run((), onTerminate: (e) => errors = e);

        expect(errors![0].error, "random error");
      },
    );

    test(
      'delivers termination when exception is thrown',
      () {
        List<ContError>? errors = null;
        final cont = Cont.fromRun<(), int>((
          runtime,
          observer,
        ) {
          throw "random error";
        });

        expect(errors, null);
        cont.run((), onTerminate: (e) => errors = e);

        expect(errors![0].error, "random error");
      },
    );

    test('respects onValue idempotency', () {
      var value = 0;
      final cont = Cont.fromRun<(), int>((
        runtime,
        observer,
      ) {
        observer.onValue(15);
        observer.onValue(20);
      });

      expect(value, 0);
      cont.run((), onValue: (v) => value = v);
      expect(value, 15);
    });

    test('respects onTerminate idempotency', () {
      List<ContError>? errors = null;
      final cont = Cont.fromRun<(), int>((
        runtime,
        observer,
      ) {
        observer.onTerminate([
          ContError("random error", StackTrace.current),
        ]);
        observer.onTerminate([
          ContError("random error2", StackTrace.current),
        ]);
      });

      expect(errors, null);
      cont.run((), onTerminate: (e) => errors = e);

      expect(errors![0].error, 'random error');
    });

    test(
      'respects shared idempotency between onValue and onTerminate',
      () {
        var value = 0;
        List<ContError>? errors = null;
        final cont = Cont.fromRun<(), int>((
          runtime,
          observer,
        ) {
          observer.onValue(15);
          observer.onTerminate([
            ContError("random error", StackTrace.current),
          ]);
        });

        expect(errors, null);
        expect(value, 0);

        cont.run(
          (),
          onTerminate: (e) => errors = e,
          onValue: (v) => value = v,
        );

        expect(errors, null);
        expect(value, 15);
      },
    );

    test(
      'respects shared idempotency between onTerminate and onValue',
      () {
        var value = 0;
        List<ContError>? errors = null;
        final cont = Cont.fromRun<(), int>((
          runtime,
          observer,
        ) {
          observer.onTerminate([
            ContError("random error", StackTrace.current),
          ]);
          observer.onValue(15);
        });

        expect(errors, null);
        expect(value, 0);

        cont.run(
          (),
          onTerminate: (e) => errors = e,
          onValue: (v) => value = v,
        );

        expect(value, 0);
        expect(errors![0].error, 'random error');
      },
    );

    test('passes environment correctly', () {
      final cont = Cont.fromRun<int, ()>((
        runtime,
        observer,
      ) {
        expect(runtime.env(), 15);
      });

      cont.run(15);
    });

    test('provides defensive copy of error list', () {
      final errors0 = [0, 1, 2, 3]
          .map(
            (value) => ContError(value, StackTrace.current),
          )
          .toList();
      List<ContError>? errors1 = null;

      final cont = Cont.fromRun<(), int>((
        runtime,
        observer,
      ) {
        observer.onTerminate(errors0);
      });

      expect(errors0.map((error) => error.error).toList(), [
        0,
        1,
        2,
        3,
      ]);
      expect(errors1, null);

      cont.run(
        (),
        onTerminate: (errors) {
          errors.add(ContError(4, StackTrace.current));
          errors1 = errors;
        },
      );

      expect(errors0.map((error) => error.error).toList(), [
        0,
        1,
        2,
        3,
      ]);
      expect(
        errors1!.map((error) => error.error).toList(),
        [0, 1, 2, 3, 4],
      );
    });

    test('blocks execution after cancellation', () {
      int value = 0;

      final List<void Function()> buffer = [];
      void flush() {
        for (final value in buffer) {
          value();
        }
        buffer.clear();
      }

      final cont = Cont.fromRun<(), int>((
        runtime,
        observer,
      ) {
        buffer.add(() {
          if (runtime.isCancelled()) {
            return;
          }
          observer.onValue(10);
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

    test(
      'triggers onPanic when onValue callback throws',
      () {
        ContError? panic;

        final cont = Cont.fromRun<(), int>((
          runtime,
          observer,
        ) {
          observer.onValue(10);
        });

        cont.run(
          (),
          onPanic: (error) => panic = error,
          onValue: (v) {
            throw 'value callback error';
          },
        );

        expect(panic!.error, 'value callback error');
      },
    );

    test(
      'triggers onPanic when onTerminate callback throws',
      () {
        ContError? panic;

        final cont = Cont.fromRun<(), int>((
          runtime,
          observer,
        ) {
          observer.onTerminate([]);
        });

        cont.run(
          (),
          onPanic: (error) => panic = error,
          onTerminate: (errors) {
            throw 'terminate callback error';
          },
        );

        expect(panic!.error, 'terminate callback error');
      },
    );

    test(
      'triggers fallback panic when onPanic throws via onValue',
      () async {
        Object? caughtError;

        runZonedGuarded(
          () {
            final cont = Cont.fromRun<(), int>((
              runtime,
              observer,
            ) {
              observer.onValue(10);
            });

            cont.run(
              (),
              onPanic: (error) {
                throw 'onPanic also fails';
              },
              onValue: (v) {
                throw 'value callback error';
              },
            );
          },
          (error, stack) {
            caughtError = error;
          },
        );

        await Future(() {});
        expect(caughtError, 'onPanic also fails');
      },
    );

    test(
      'triggers fallback panic when onPanic throws via onTerminate',
      () async {
        Object? caughtError;

        runZonedGuarded(
          () {
            final cont = Cont.fromRun<(), int>((
              runtime,
              observer,
            ) {
              observer.onTerminate([]);
            });

            cont.run(
              (),
              onPanic: (error) {
                throw 'onPanic also fails';
              },
              onTerminate: (errors) {
                throw 'terminate callback error';
              },
            );
          },
          (error, stack) {
            caughtError = error;
          },
        );

        await Future(() {});
        expect(caughtError, 'onPanic also fails');
      },
    );

    test(
      'respects idempotency when throwing after onValue',
      () {
        var value = 0;
        List<ContError>? errors;

        final cont = Cont.fromRun<(), int>((
          runtime,
          observer,
        ) {
          observer.onValue(15);
          throw 'error after value';
        });

        cont.run(
          (),
          onValue: (v) => value = v,
          onTerminate: (e) => errors = e,
        );

        expect(value, 15);
        expect(errors, null);
      },
    );

    test(
      'respects idempotency when throwing after onTerminate',
      () {
        List<ContError>? errors;

        final cont = Cont.fromRun<(), int>((
          runtime,
          observer,
        ) {
          observer.onTerminate([
            ContError("first error", StackTrace.current),
          ]);
          throw 'error after terminate';
        });

        cont.run((), onTerminate: (e) => errors = e);

        expect(errors!.length, 1);
        expect(errors![0].error, 'first error');
      },
    );
  });
}
