import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.elseZipWithEnv', () {
    test('recovers with env access', () {
      String? value;

      Cont.stop<String, String>([
            ContError.capture('err'),
          ])
          .elseZipWithEnv(
            (env, errors) => Cont.of('$env: recovered'),
          )
          .run('hello', onThen: (val) => value = val);

      expect(value, 'hello: recovered');
    });

    test('combines errors when both fail', () {
      List<ContError>? errors;

      Cont.stop<String, int>([
            ContError.capture('err1'),
          ])
          .elseZipWithEnv((env, e) {
            return Cont.stop<String, int>([
              ContError.capture('err2-$env'),
            ]);
          })
          .run('cfg', onElse: (e) => errors = e);

      expect(errors!.length, 2);
      expect(errors![0].error, 'err1');
      expect(errors![1].error, 'err2-cfg');
    });

    test('never executes on value path', () {
      bool called = false;
      int? value;

      Cont.of<String, int>(42)
          .elseZipWithEnv((env, errors) {
            called = true;
            return Cont.of(0);
          })
          .run('hello', onThen: (val) => value = val);

      expect(called, false);
      expect(value, 42);
    });

    test('receives defensive copy of errors', () {
      final originalErrors = [ContError.capture('err1')];
      List<ContError>? receivedErrors;

      Cont.stop<String, int>(originalErrors)
          .elseZipWithEnv((env, errors) {
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
      final cont = Cont.stop<String, int>()
          .elseZipWithEnv((env, errors) {
            callCount++;
            return Cont.of(env.length);
          });

      int? value1;
      cont.run('hi', onThen: (val) => value1 = val);
      expect(value1, 2);
      expect(callCount, 1);

      int? value2;
      cont.run('hello', onThen: (val) => value2 = val);
      expect(value2, 5);
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
          }).elseZipWithEnv((env, errors) {
            fallbackCalled = true;
            return Cont.of(42);
          });

      final token = cont.run('hello');

      token.cancel();
      flush();

      expect(fallbackCalled, false);
    });
  });

  group('Cont.elseZipWithEnv0', () {
    test('provides env only', () {
      String? value;

      Cont.stop<String, String>()
          .elseZipWithEnv0(
            (env) => Cont.of('recovered: $env'),
          )
          .run('hello', onThen: (val) => value = val);

      expect(value, 'recovered: hello');
    });

    test(
      'behaves like elseZipWithEnv with ignored errors',
      () {
        int? value1;
        int? value2;

        final cont1 = Cont.stop<String, int>()
            .elseZipWithEnv0((env) => Cont.of(env.length));
        final cont2 = Cont.stop<String, int>()
            .elseZipWithEnv(
              (env, _) => Cont.of(env.length),
            );

        cont1.run('hello', onThen: (val) => value1 = val);
        cont2.run('hello', onThen: (val) => value2 = val);

        expect(value1, value2);
      },
    );
  });
}
