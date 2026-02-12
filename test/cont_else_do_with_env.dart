import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.elseDoWithEnv', () {
    test('provides env and errors on termination', () {
      String? value;

      Cont.stop<String, String>([
            ContError.capture('err'),
          ])
          .elseDoWithEnv(
            (env, errors) =>
                Cont.of('$env: ${errors.first.error}'),
          )
          .run('hello', onThen: (val) => value = val);

      expect(value, 'hello: err');
    });

    test('never executes on value path', () {
      bool called = false;
      String? value;

      Cont.of<String, String>('original')
          .elseDoWithEnv((env, errors) {
            called = true;
            return Cont.of('fallback');
          })
          .run('hello', onThen: (val) => value = val);

      expect(called, false);
      expect(value, 'original');
    });

    test(
      'propagates fallback errors when fallback also fails',
      () {
        List<ContError>? errors;

        Cont.stop<String, int>([
              ContError.capture('original'),
            ])
            .elseDoWithEnv((env, e) {
              return Cont.stop<String, int>([
                ContError.capture('fallback-$env'),
              ]);
            })
            .run('cfg', onElse: (e) => errors = e);

        expect(errors!.length, 1);
        expect(errors![0].error, 'fallback-cfg');
      },
    );

    test('receives defensive copy of errors', () {
      final originalErrors = [ContError.capture('err1')];
      List<ContError>? receivedErrors;

      Cont.stop<String, int>(originalErrors)
          .elseDoWithEnv((env, errors) {
            receivedErrors = errors;
            errors.add(ContError.capture('err2'));
            return Cont.of(0);
          })
          .run('hello');

      expect(originalErrors.length, 1);
      expect(receivedErrors!.length, 2);
    });

    test('supports multiple runs with different envs', () {
      var callCount = 0;
      final cont = Cont.stop<String, String>()
          .elseDoWithEnv((env, errors) {
            callCount++;
            return Cont.of('recovered: $env');
          });

      String? value1;
      cont.run('first', onThen: (val) => value1 = val);
      expect(value1, 'recovered: first');
      expect(callCount, 1);

      String? value2;
      cont.run('second', onThen: (val) => value2 = val);
      expect(value2, 'recovered: second');
      expect(callCount, 2);
    });

    test('prevents fallback after cancellation', () {
      bool fallbackCalled = false;

      final List<void Function()> buffer = [];
      void flush() {
        for (final fn in buffer) {
          fn();
        }
        buffer.clear();
      }

      final cont =
          Cont.fromRun<String, int>((runtime, observer) {
            buffer.add(() {
              if (runtime.isCancelled()) return;
              observer.onElse([
                ContError.capture('error'),
              ]);
            });
          }).elseDoWithEnv((env, errors) {
            fallbackCalled = true;
            return Cont.of(42);
          });

      final token = cont.run('hello');

      token.cancel();
      flush();

      expect(fallbackCalled, false);
    });
  });

  group('Cont.elseDoWithEnv0', () {
    test('provides env only', () {
      String? value;

      Cont.stop<String, String>()
          .elseDoWithEnv0(
            (env) => Cont.of('recovered: $env'),
          )
          .run('hello', onThen: (val) => value = val);

      expect(value, 'recovered: hello');
    });

    test(
      'behaves like elseDoWithEnv with ignored errors',
      () {
        String? value1;
        String? value2;

        final cont1 = Cont.stop<String, String>()
            .elseDoWithEnv0(
              (env) => Cont.of('recovered: $env'),
            );
        final cont2 = Cont.stop<String, String>()
            .elseDoWithEnv(
              (env, _) => Cont.of('recovered: $env'),
            );

        cont1.run('hello', onThen: (val) => value1 = val);
        cont2.run('hello', onThen: (val) => value2 = val);

        expect(value1, value2);
      },
    );
  });
}
