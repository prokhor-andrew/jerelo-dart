import 'dart:async';

import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.fromRun', () {
    test('Cont.fromRun with ContObserver<Never>', () {
      final cont = Cont.fromRun<(), Never>((
        runtime,
        observer,
      ) {
        observer.onElse();
      });

      cont.run(
        (),
        onElse: (errors) {
          expect(errors, []);
        },
        onThen: (_) {
          fail('Should not be called');
        },
      );
    });

    test('Cont.fromRun is run properly', () {
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

    test('Cont.fromRun onThen channel used', () {
      var value = 15;
      final cont = Cont.fromRun<(), int>((
        runtime,
        observer,
      ) {
        observer.onThen(0);
      });

      expect(value, 15);
      cont.run((), onThen: (v) => value = v);
      expect(value, 0);
    });

    test(
      'Cont.fromRun onElse empty channel used manually',
      () {
        List<ContError>? errors = null;
        final cont = Cont.fromRun<(), int>((
          runtime,
          observer,
        ) {
          observer.onElse([]);
        });

        expect(errors, null);
        cont.run((), onElse: (e) => errors = e);
        expect(errors, []);
      },
    );

    test(
      'Cont.fromRun onElse error channel used manually',
      () {
        List<ContError>? errors = null;
        final cont = Cont.fromRun<(), int>((
          runtime,
          observer,
        ) {
          observer.onElse([
            ContError.capture("random error"),
          ]);
        });

        expect(errors, null);
        cont.run((), onElse: (e) => errors = e);

        expect(errors![0].error, "random error");
      },
    );

    test(
      'Cont.fromRun onElse error channel used when throws',
      () {
        List<ContError>? errors = null;
        final cont = Cont.fromRun<(), int>((
          runtime,
          observer,
        ) {
          throw "random error";
        });

        expect(errors, null);
        cont.run((), onElse: (e) => errors = e);

        expect(errors![0].error, "random error");
      },
    );

    test('Cont.fromRun onThen idempotent', () {
      var value = 0;
      final cont = Cont.fromRun<(), int>((
        runtime,
        observer,
      ) {
        observer.onThen(15);
        observer.onThen(20);
      });

      expect(value, 0);
      cont.run((), onThen: (v) => value = v);
      expect(value, 15);
    });

    test('Cont.fromRun onElse idempotent', () {
      List<ContError>? errors = null;
      final cont = Cont.fromRun<(), int>((
        runtime,
        observer,
      ) {
        observer.onElse([
          ContError.capture("random error"),
        ]);
        observer.onElse([
          ContError.capture("random error2"),
        ]);
      });

      expect(errors, null);
      cont.run((), onElse: (e) => errors = e);

      expect(errors![0].error, 'random error');
    });

    test(
      'Cont.fromRun onThen and onElse share idempotency',
      () {
        var value = 0;
        List<ContError>? errors = null;
        final cont = Cont.fromRun<(), int>((
          runtime,
          observer,
        ) {
          observer.onThen(15);
          observer.onElse([
            ContError.capture("random error"),
          ]);
        });

        expect(errors, null);
        expect(value, 0);

        cont.run(
          (),
          onElse: (e) => errors = e,
          onThen: (v) => value = v,
        );

        expect(errors, null);
        expect(value, 15);
      },
    );

    test(
      'Cont.fromRun onElse and onThen share idempotency',
      () {
        var value = 0;
        List<ContError>? errors = null;
        final cont = Cont.fromRun<(), int>((
          runtime,
          observer,
        ) {
          observer.onElse([
            ContError.capture("random error"),
          ]);
          observer.onThen(15);
        });

        expect(errors, null);
        expect(value, 0);

        cont.run(
          (),
          onElse: (e) => errors = e,
          onThen: (v) => value = v,
        );

        expect(value, 0);
        expect(errors![0].error, 'random error');
      },
    );

    test('Cont.fromRun env passed properly', () {
      final cont = Cont.fromRun<int, ()>((
        runtime,
        observer,
      ) {
        expect(runtime.env(), 15);
      });

      cont.run(15);
    });

    test('Cont.fromRun errors defensive copy', () {
      final errors0 = [
        0,
        1,
        2,
        3,
      ].map((value) => ContError.capture(value)).toList();
      List<ContError>? errors1 = null;

      final cont = Cont.fromRun<(), int>((
        runtime,
        observer,
      ) {
        observer.onElse(errors0);
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
        onElse: (errors) {
          errors.add(ContError.capture(4));
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

    test('Cont.fromRun cancellation stops execution', () {
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
          observer.onThen(10);
        });
      });

      expect(value, 0);
      final token = cont.run(
        (),
        onThen: (val) => value = val,
      );
      expect(value, 0);
      token.cancel();
      flush();
      expect(value, 0);
    });

    test(
      'Cont.fromRun onPanic when onThen callback throws',
      () {
        ContError? panic;

        final cont = Cont.fromRun<(), int>((
          runtime,
          observer,
        ) {
          observer.onThen(10);
        });

        cont.run(
          (),
          onPanic: (error) => panic = error,
          onThen: (v) {
            throw 'value callback error';
          },
        );

        expect(panic!.error, 'value callback error');
      },
    );

    test(
      'Cont.fromRun onPanic when onElse callback throws',
      () {
        ContError? panic;

        final cont = Cont.fromRun<(), int>((
          runtime,
          observer,
        ) {
          observer.onElse([]);
        });

        cont.run(
          (),
          onPanic: (error) => panic = error,
          onElse: (errors) {
            throw 'terminate callback error';
          },
        );

        expect(panic!.error, 'terminate callback error');
      },
    );

    test(
      'Cont.fromRun fallback panic when onPanic throws via onThen',
      () async {
        Object? caughtError;

        runZonedGuarded(
          () {
            final cont = Cont.fromRun<(), int>((
              runtime,
              observer,
            ) {
              observer.onThen(10);
            });

            cont.run(
              (),
              onPanic: (error) {
                throw 'onPanic also fails';
              },
              onThen: (v) {
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
      'Cont.fromRun fallback panic when onPanic throws via onElse',
      () async {
        Object? caughtError;

        runZonedGuarded(
          () {
            final cont = Cont.fromRun<(), int>((
              runtime,
              observer,
            ) {
              observer.onElse([]);
            });

            cont.run(
              (),
              onPanic: (error) {
                throw 'onPanic also fails';
              },
              onElse: (errors) {
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
      'Cont.fromRun throw after onThen is idempotent',
      () {
        var value = 0;
        List<ContError>? errors;

        final cont = Cont.fromRun<(), int>((
          runtime,
          observer,
        ) {
          observer.onThen(15);
          throw 'error after value';
        });

        cont.run(
          (),
          onThen: (v) => value = v,
          onElse: (e) => errors = e,
        );

        expect(value, 15);
        expect(errors, null);
      },
    );

    test(
      'Cont.fromRun throw after onElse is idempotent',
      () {
        List<ContError>? errors;

        final cont = Cont.fromRun<(), int>((
          runtime,
          observer,
        ) {
          observer.onElse([
            ContError.capture("first error"),
          ]);
          throw 'error after terminate';
        });

        cont.run((), onElse: (e) => errors = e);

        expect(errors!.length, 1);
        expect(errors![0].error, 'first error');
      },
    );

    test(
      'Cont.fromRun guardedValue blocked after cancellation',
      () {
        var value = 0;

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
            observer.onThen(10);
          });
        });

        expect(value, 0);
        final token = cont.run(
          (),
          onThen: (val) => value = val,
        );
        expect(value, 0);
        token.cancel();
        flush();
        expect(value, 0);
      },
    );

    test(
      'Cont.fromRun guardedTerminate blocked after cancellation',
      () {
        List<ContError>? errors;

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
            observer.onElse([
              ContError.capture("error"),
            ]);
          });
        });

        expect(errors, null);
        final token = cont.run(
          (),
          onElse: (e) => errors = e,
        );
        expect(errors, null);
        token.cancel();
        flush();
        expect(errors, null);
      },
    );
  });
}
