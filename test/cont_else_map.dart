import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.elseMap', () {
    test('transforms termination errors', () {
      List<ContError>? errors;

      Cont.stop<(), int>([ContError.capture('original')])
          .elseMap(
            (e) => [
              ...e,
              ContError.capture('added'),
            ],
          )
          .run((), onElse: (e) => errors = e);

      expect(errors!.length, 2);
      expect(errors![0].error, 'original');
      expect(errors![1].error, 'added');
    });

    test('replaces errors entirely', () {
      List<ContError>? errors;

      Cont.stop<(), int>([
            ContError.capture('err1'),
            ContError.capture('err2'),
          ])
          .elseMap(
            (_) => [ContError.capture('replaced')],
          )
          .run((), onElse: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'replaced');
    });

    test('can filter errors', () {
      List<ContError>? errors;

      Cont.stop<(), int>([
            ContError.capture('keep'),
            ContError.capture('remove'),
            ContError.capture('keep'),
          ])
          .elseMap(
            (e) =>
                e.where((err) => err.error == 'keep').toList(),
          )
          .run((), onElse: (e) => errors = e);

      expect(errors!.length, 2);
      expect(errors![0].error, 'keep');
      expect(errors![1].error, 'keep');
    });

    test('never executes on value path', () {
      bool called = false;
      int? value;

      Cont.of<(), int>(42)
          .elseMap((errors) {
            called = true;
            return errors;
          })
          .run((), onThen: (val) => value = val);

      expect(called, false);
      expect(value, 42);
    });

    test('terminates when function throws', () {
      ContError? error;

      Cont.stop<(), int>([ContError.capture('original')])
          .elseMap((errors) {
            throw 'Map Error';
          })
          .run(
            (),
            onElse: (errors) => error = errors.first,
          );

      expect(error!.error, 'Map Error');
    });

    test('works with empty error list', () {
      List<ContError>? errors;

      Cont.stop<(), int>([])
          .elseMap(
            (e) => [
              ...e,
              ContError.capture('added'),
            ],
          )
          .run((), onElse: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'added');
    });

    test('can transform to empty error list', () {
      List<ContError>? errors;

      Cont.stop<(), int>([ContError.capture('err')])
          .elseMap((_) => [])
          .run((), onElse: (e) => errors = e);

      expect(errors, isEmpty);
    });

    test('never calls onPanic', () {
      Cont.stop<(), int>([ContError.capture('err')])
          .elseMap((e) => e)
          .run(
            (),
            onPanic: (_) => fail('Should not be called'),
          );
    });

    test('supports multiple runs', () {
      var callCount = 0;
      final cont =
          Cont.stop<(), int>([
            ContError.capture('err'),
          ]).elseMap((e) {
            callCount++;
            return e;
          });

      cont.run((), onElse: (_) {});
      expect(callCount, 1);

      cont.run((), onElse: (_) {});
      expect(callCount, 2);
    });

    test('cancellation prevents elseMap execution', () {
      bool mapCalled = false;

      final List<void Function()> buffer = [];
      void flush() {
        for (final fn in buffer) {
          fn();
        }
        buffer.clear();
      }

      final cont = Cont.fromRun<(), int>((runtime, observer) {
        buffer.add(() {
          if (runtime.isCancelled()) return;
          observer.onElse([ContError.capture('err')]);
        });
      }).elseMap((errors) {
        mapCalled = true;
        return errors;
      });

      final token = cont.run((), onElse: (_) {});

      token.cancel();
      flush();

      expect(mapCalled, false);
    });
  });

  group('Cont.elseMap0', () {
    test('replaces errors without examining originals', () {
      List<ContError>? errors;

      Cont.stop<(), int>([ContError.capture('original')])
          .elseMap0(
            () => [ContError.capture('replaced')],
          )
          .run((), onElse: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'replaced');
    });

    test(
      'behaves like elseMap with ignored argument',
      () {
        List<ContError>? errors1;
        List<ContError>? errors2;

        Cont.stop<(), int>([ContError.capture('err')])
            .elseMap0(
              () => [ContError.capture('replaced')],
            )
            .run((), onElse: (e) => errors1 = e);

        Cont.stop<(), int>([ContError.capture('err')])
            .elseMap(
              (_) => [ContError.capture('replaced')],
            )
            .run((), onElse: (e) => errors2 = e);

        expect(errors1!.length, errors2!.length);
        expect(errors1![0].error, errors2![0].error);
      },
    );

    test('never executes on value path', () {
      bool called = false;

      Cont.of<(), int>(42)
          .elseMap0(() {
            called = true;
            return [];
          })
          .run((), onThen: (_) {});

      expect(called, false);
    });
  });

  group('Cont.elseMapWithEnv', () {
    test(
      'provides both env and errors to transform function',
      () {
        String? receivedEnv;
        List<ContError>? receivedErrors;

        Cont.stop<String, int>([ContError.capture('err')])
            .elseMapWithEnv((env, errors) {
              receivedEnv = env;
              receivedErrors = errors;
              return errors;
            })
            .run('hello', onElse: (_) {});

        expect(receivedEnv, 'hello');
        expect(receivedErrors!.length, 1);
        expect(receivedErrors![0].error, 'err');
      },
    );

    test('transforms errors using env', () {
      List<ContError>? errors;

      Cont.stop<String, int>([ContError.capture('err')])
          .elseMapWithEnv(
            (env, e) => [ContError.capture('$env: ${e.first.error}')],
          )
          .run('ctx', onElse: (e) => errors = e);

      expect(errors![0].error, 'ctx: err');
    });

    test('never executes on value path', () {
      bool called = false;

      Cont.of<String, int>(42)
          .elseMapWithEnv((env, errors) {
            called = true;
            return errors;
          })
          .run('hello', onThen: (_) {});

      expect(called, false);
    });

    test(
      'supports multiple runs with different envs',
      () {
        List<ContError>? errors1;
        List<ContError>? errors2;

        final cont =
            Cont.stop<String, int>([
              ContError.capture('err'),
            ]).elseMapWithEnv(
              (env, e) => [ContError.capture('$env')],
            );

        cont.run('first', onElse: (e) => errors1 = e);
        cont.run('second', onElse: (e) => errors2 = e);

        expect(errors1![0].error, 'first');
        expect(errors2![0].error, 'second');
      },
    );
  });

  group('Cont.elseMapWithEnv0', () {
    test('provides only env to transform function', () {
      String? receivedEnv;

      Cont.stop<String, int>([ContError.capture('err')])
          .elseMapWithEnv0((env) {
            receivedEnv = env;
            return [ContError.capture('replaced')];
          })
          .run('hello', onElse: (_) {});

      expect(receivedEnv, 'hello');
    });

    test('transforms errors using env only', () {
      List<ContError>? errors;

      Cont.stop<String, int>([ContError.capture('err')])
          .elseMapWithEnv0(
            (env) => [ContError.capture('env: $env')],
          )
          .run('ctx', onElse: (e) => errors = e);

      expect(errors![0].error, 'env: ctx');
    });

    test(
      'behaves like elseMapWithEnv with ignored errors',
      () {
        List<ContError>? errors1;
        List<ContError>? errors2;

        Cont.stop<String, int>([ContError.capture('err')])
            .elseMapWithEnv0(
              (env) => [ContError.capture('$env')],
            )
            .run('hello', onElse: (e) => errors1 = e);

        Cont.stop<String, int>([ContError.capture('err')])
            .elseMapWithEnv(
              (env, _) => [ContError.capture('$env')],
            )
            .run('hello', onElse: (e) => errors2 = e);

        expect(errors1![0].error, errors2![0].error);
      },
    );

    test('never executes on value path', () {
      bool called = false;

      Cont.of<String, int>(42)
          .elseMapWithEnv0((env) {
            called = true;
            return [];
          })
          .run('hello', onThen: (_) {});

      expect(called, false);
    });
  });

  group('Cont.elseMapTo', () {
    test('replaces errors with fixed list', () {
      List<ContError>? errors;

      Cont.stop<(), int>([
            ContError.capture('original'),
          ])
          .elseMapTo([ContError.capture('fixed')])
          .run((), onElse: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'fixed');
    });

    test('replaces with empty list', () {
      List<ContError>? errors;

      Cont.stop<(), int>([ContError.capture('err')])
          .elseMapTo([])
          .run((), onElse: (e) => errors = e);

      expect(errors, isEmpty);
    });

    test('never executes on value path', () {
      int? value;

      Cont.of<(), int>(42)
          .elseMapTo([ContError.capture('fixed')])
          .run((), onThen: (val) => value = val);

      expect(value, 42);
    });

    test('defensively copies the error list', () {
      final originalErrors = [ContError.capture('err1')];
      final cont = Cont.stop<(), int>([
        ContError.capture('original'),
      ]).elseMapTo(originalErrors);

      originalErrors.add(ContError.capture('err2'));

      List<ContError>? received;
      cont.run((), onElse: (e) => received = e);

      expect(received!.length, 1);
      expect(received![0].error, 'err1');
    });

    test('supports multiple runs', () {
      var callCount = 0;
      final cont = Cont.stop<(), int>([
        ContError.capture('err'),
      ]).elseMapTo([ContError.capture('fixed')]);

      cont.run((), onElse: (_) => callCount++);
      cont.run((), onElse: (_) => callCount++);

      expect(callCount, 2);
    });

    test('never calls onPanic', () {
      Cont.stop<(), int>([ContError.capture('err')])
          .elseMapTo([ContError.capture('fixed')])
          .run(
            (),
            onPanic: (_) => fail('Should not be called'),
          );
    });
  });
}
