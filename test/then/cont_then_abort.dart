import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.abort', () {
    test('terminates with computed errors from value', () {
      List<ContError>? errors;

      Cont.of<(), int>(42)
          .abort((a) => [ContError.capture('aborted: $a')])
          .run((), onElse: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'aborted: 42');
    });

    test('does not call onThen', () {
      Cont.of<(), int>(42)
          .abort((a) => [ContError.capture('aborted')])
          .run(
            (),
            onThen: (_) => fail('Should not be called'),
            onElse: (_) {},
          );
    });

    test('passes through original termination', () {
      List<ContError>? errors;
      bool abortCalled = false;

      Cont.stop<(), int>([ContError.capture('original')])
          .abort((a) {
            abortCalled = true;
            return [ContError.capture('aborted')];
          })
          .run((), onElse: (e) => errors = e);

      expect(abortCalled, false);
      expect(errors!.length, 1);
      expect(errors![0].error, 'original');
    });

    test('terminates with multiple errors', () {
      List<ContError>? errors;

      Cont.of<(), int>(42)
          .abort(
            (a) => [
              ContError.capture('err1'),
              ContError.capture('err2'),
            ],
          )
          .run((), onElse: (e) => errors = e);

      expect(errors!.length, 2);
      expect(errors![0].error, 'err1');
      expect(errors![1].error, 'err2');
    });

    test('terminates with empty errors', () {
      List<ContError>? errors;

      Cont.of<(), int>(
        42,
      ).abort((a) => []).run((), onElse: (e) => errors = e);

      expect(errors, isEmpty);
    });

    test('terminates when function throws', () {
      ContError? error;

      Cont.of<(), int>(42)
          .abort((a) {
            throw 'Abort Error';
          })
          .run(
            (),
            onElse: (errors) => error = errors.first,
          );

      expect(error!.error, 'Abort Error');
    });

    test('never calls onPanic', () {
      Cont.of<(), int>(42)
          .abort((a) => [ContError.capture('aborted')])
          .run(
            (),
            onPanic: (_) => fail('Should not be called'),
          );
    });

    test('supports multiple runs', () {
      var callCount = 0;
      final cont = Cont.of<(), int>(42).abort((a) {
        callCount++;
        return [ContError.capture('aborted')];
      });

      cont.run((), onElse: (_) {});
      expect(callCount, 1);

      cont.run((), onElse: (_) {});
      expect(callCount, 2);
    });

    test('cancellation prevents abort execution', () {
      bool abortCalled = false;

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
              observer.onThen(42);
            });
          }).abort((a) {
            abortCalled = true;
            return [ContError.capture('aborted')];
          });

      final token = cont.run((), onElse: (_) {});

      token.cancel();
      flush();

      expect(abortCalled, false);
    });
  });

  group('Cont.abort0', () {
    test(
      'terminates with errors from zero-argument function',
      () {
        List<ContError>? errors;

        Cont.of<(), int>(42)
            .abort0(() => [ContError.capture('aborted')])
            .run((), onElse: (e) => errors = e);

        expect(errors!.length, 1);
        expect(errors![0].error, 'aborted');
      },
    );

    test('ignores the value', () {
      List<ContError>? errors;

      Cont.of<(), int>(99)
          .abort0(() => [ContError.capture('fixed error')])
          .run((), onElse: (e) => errors = e);

      expect(errors![0].error, 'fixed error');
    });

    test('behaves like abort with ignored argument', () {
      List<ContError>? errors1;
      List<ContError>? errors2;

      Cont.of<(), int>(42)
          .abort0(() => [ContError.capture('aborted')])
          .run((), onElse: (e) => errors1 = e);

      Cont.of<(), int>(42)
          .abort((_) => [ContError.capture('aborted')])
          .run((), onElse: (e) => errors2 = e);

      expect(errors1!.length, errors2!.length);
      expect(errors1![0].error, errors2![0].error);
    });

    test('passes through original termination', () {
      bool abort0Called = false;

      Cont.stop<(), int>([ContError.capture('original')])
          .abort0(() {
            abort0Called = true;
            return [ContError.capture('aborted')];
          })
          .run((), onElse: (_) {});

      expect(abort0Called, false);
    });
  });

  group('Cont.abortWithEnv', () {
    test(
      'provides both env and value to error function',
      () {
        String? receivedEnv;
        int? receivedValue;

        Cont.of<String, int>(42)
            .abortWithEnv((env, a) {
              receivedEnv = env;
              receivedValue = a;
              return [ContError.capture('aborted')];
            })
            .run('hello', onElse: (_) {});

        expect(receivedEnv, 'hello');
        expect(receivedValue, 42);
      },
    );

    test(
      'terminates with errors computed from env and value',
      () {
        List<ContError>? errors;

        Cont.of<String, int>(42)
            .abortWithEnv(
              (env, a) => [ContError.capture('$env: $a')],
            )
            .run('ctx', onElse: (e) => errors = e);

        expect(errors![0].error, 'ctx: 42');
      },
    );

    test('passes through original termination', () {
      bool called = false;

      Cont.stop<String, int>([
            ContError.capture('original'),
          ])
          .abortWithEnv((env, a) {
            called = true;
            return [ContError.capture('aborted')];
          })
          .run('hello', onElse: (_) {});

      expect(called, false);
    });

    test('supports multiple runs with different envs', () {
      List<ContError>? errors1;
      List<ContError>? errors2;

      final cont = Cont.of<String, int>(42).abortWithEnv(
        (env, a) => [ContError.capture('$env: $a')],
      );

      cont.run('first', onElse: (e) => errors1 = e);
      cont.run('second', onElse: (e) => errors2 = e);

      expect(errors1![0].error, 'first: 42');
      expect(errors2![0].error, 'second: 42');
    });
  });

  group('Cont.abortWithEnv0', () {
    test('provides only env to error function', () {
      String? receivedEnv;

      Cont.of<String, int>(42)
          .abortWithEnv0((env) {
            receivedEnv = env;
            return [ContError.capture('aborted')];
          })
          .run('hello', onElse: (_) {});

      expect(receivedEnv, 'hello');
    });

    test(
      'terminates with errors computed from env only',
      () {
        List<ContError>? errors;

        Cont.of<String, int>(42)
            .abortWithEnv0(
              (env) => [ContError.capture('env: $env')],
            )
            .run('ctx', onElse: (e) => errors = e);

        expect(errors![0].error, 'env: ctx');
      },
    );

    test(
      'behaves like abortWithEnv with ignored value',
      () {
        List<ContError>? errors1;
        List<ContError>? errors2;

        Cont.of<String, int>(42)
            .abortWithEnv0(
              (env) => [ContError.capture('$env')],
            )
            .run('hello', onElse: (e) => errors1 = e);

        Cont.of<String, int>(42)
            .abortWithEnv(
              (env, _) => [ContError.capture('$env')],
            )
            .run('hello', onElse: (e) => errors2 = e);

        expect(errors1![0].error, errors2![0].error);
      },
    );

    test('passes through original termination', () {
      bool called = false;

      Cont.stop<String, int>([
            ContError.capture('original'),
          ])
          .abortWithEnv0((env) {
            called = true;
            return [ContError.capture('aborted')];
          })
          .run('hello', onElse: (_) {});

      expect(called, false);
    });
  });

  group('Cont.abortWith', () {
    test('terminates with fixed errors', () {
      List<ContError>? errors;

      Cont.of<(), int>(42)
          .abortWith([ContError.capture('fixed')])
          .run((), onElse: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'fixed');
    });

    test('terminates with empty fixed errors', () {
      List<ContError>? errors;

      Cont.of<(), int>(
        42,
      ).abortWith([]).run((), onElse: (e) => errors = e);

      expect(errors, isEmpty);
    });

    test('passes through original termination', () {
      List<ContError>? errors;

      Cont.stop<(), int>([ContError.capture('original')])
          .abortWith([ContError.capture('fixed')])
          .run((), onElse: (e) => errors = e);

      expect(errors![0].error, 'original');
    });

    test('defensively copies the error list', () {
      final originalErrors = [ContError.capture('err1')];
      final cont = Cont.of<(), int>(
        42,
      ).abortWith(originalErrors);

      originalErrors.add(ContError.capture('err2'));

      List<ContError>? received;
      cont.run((), onElse: (e) => received = e);

      expect(received!.length, 1);
      expect(received![0].error, 'err1');
    });

    test('supports multiple runs', () {
      var callCount = 0;
      final cont = Cont.of<(), int>(
        42,
      ).abortWith([ContError.capture('fixed')]);

      cont.run((), onElse: (_) => callCount++);
      cont.run((), onElse: (_) => callCount++);

      expect(callCount, 2);
    });

    test('never calls onPanic', () {
      Cont.of<(), int>(42)
          .abortWith([ContError.capture('fixed')])
          .run(
            (),
            onPanic: (_) => fail('Should not be called'),
          );
    });
  });
}
