import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.fromDeferred', () {
    test('Cont.fromDeferred runs successfully', () {
      var isRun = false;
      final cont = Cont.fromDeferred<(), ()>(() {
        isRun = true;
        return Cont.of(());
      });

      expect(isRun, false);
      cont.run(());
      expect(isRun, true);
    });

    test('Cont.fromDeferred onThen channel used', () {
      var value = 0;
      final cont = Cont.fromDeferred<(), int>(() {
        return Cont.of(15);
      });

      expect(value, 0);
      cont.run((), onThen: (v) => value = v);
      expect(value, 15);
    });

    test('Cont.fromDeferred onElse error channel used', () {
      List<ContError>? errors;
      final cont = Cont.fromDeferred<(), int>(() {
        return Cont.stop([
          ContError.capture("deferred error"),
        ]);
      });

      expect(errors, null);
      cont.run((), onElse: (e) => errors = e);
      expect(errors![0].error, "deferred error");
    });

    test('Cont.fromDeferred onElse empty channel used', () {
      List<ContError>? errors;
      final cont = Cont.fromDeferred<(), int>(() {
        return Cont.stop();
      });

      expect(errors, null);
      cont.run((), onElse: (e) => errors = e);
      expect(errors, []);
    });

    test('Cont.fromDeferred onElse when thunk throws', () {
      List<ContError>? errors;
      final cont = Cont.fromDeferred<(), int>(() {
        throw "thunk error";
      });

      expect(errors, null);
      cont.run((), onElse: (e) => errors = e);
      expect(errors![0].error, "thunk error");
    });

    test('Cont.fromDeferred env passed properly', () {
      var envValue = 0;
      final cont = Cont.fromDeferred<int, ()>(() {
        return Cont.fromRun((runtime, observer) {
          envValue = runtime.env();
          observer.onThen(());
        });
      });

      expect(envValue, 0);
      cont.run(42);
      expect(envValue, 42);
    });

    test(
      'Cont.fromDeferred each run creates fresh thunk',
      () {
        var callCount = 0;
        final cont = Cont.fromDeferred<(), int>(() {
          callCount += 1;
          return Cont.of(callCount);
        });

        var value1 = 0;
        var value2 = 0;

        cont.run((), onThen: (v) => value1 = v);
        cont.run((), onThen: (v) => value2 = v);

        expect(callCount, 2);
        expect(value1, 1);
        expect(value2, 2);
      },
    );

    test(
      'Cont.fromDeferred cancellation blocks inner onThen',
      () {
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
              observer.onThen(10);
            });
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
      'Cont.fromDeferred cancellation blocks inner onElse',
      () {
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
              observer.onElse([ContError.capture("error")]);
            });
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

    test(
      'Cont.fromDeferred with Cont<E, Never> inner continuation',
      () {
        List<ContError>? errors;
        final cont = Cont.fromDeferred<(), int>(() {
          return Cont.fromRun<(), Never>((
            runtime,
            observer,
          ) {
            observer.onElse([
              ContError.capture("never error"),
            ]);
          });
        });

        cont.run(
          (),
          onElse: (e) => errors = e,
          onThen: (v) {
            fail('Should not be called');
          },
        );

        expect(errors![0].error, "never error");
      },
    );
  });
}
