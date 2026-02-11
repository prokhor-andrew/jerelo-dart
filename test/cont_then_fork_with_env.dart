import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.thenForkWithEnv', () {
    test('preserves original value', () {
      int? value;

      Cont.of<String, int>(42)
          .thenForkWithEnv((env, a) => Cont.of('$env: $a'))
          .run('hello', onValue: (val) => value = val);

      expect(value, 42);
    });

    test('provides both env and value to fork', () {
      String? receivedEnv;
      int? receivedValue;

      final List<void Function()> buffer = [];
      void flush() {
        for (final fn in buffer) {
          fn();
        }
        buffer.clear();
      }

      Cont.of<String, int>(42)
          .thenForkWithEnv((env, a) {
            return Cont.fromRun<String, ()>((
              runtime,
              observer,
            ) {
              buffer.add(() {
                receivedEnv = env;
                receivedValue = a;
                observer.onValue(());
              });
            });
          })
          .run('hello');

      expect(receivedEnv, null);
      flush();
      expect(receivedEnv, 'hello');
      expect(receivedValue, 42);
    });

    test('returns immediately without waiting', () {
      final order = <String>[];

      final List<void Function()> buffer = [];
      void flush() {
        for (final fn in buffer) {
          fn();
        }
        buffer.clear();
      }

      Cont.of<String, int>(10)
          .thenForkWithEnv((env, a) {
            return Cont.fromRun<String, ()>((
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
            'hello',
            onValue: (val) => order.add('main'),
          );

      expect(order, ['main']);
      flush();
      expect(order, ['main', 'fork']);
    });

    test('passes through termination', () {
      List<ContError>? errors;

      Cont.terminate<String, int>([
            ContError.capture('err'),
          ])
          .thenForkWithEnv((env, a) => Cont.of('$env: $a'))
          .run('hello', onTerminate: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'err');
    });

    test('never executes on termination', () {
      bool called = false;

      Cont.terminate<String, int>()
          .thenForkWithEnv((env, a) {
            called = true;
            return Cont.of(());
          })
          .run('hello', onTerminate: (_) {});

      expect(called, false);
    });
  });

  group('Cont.thenForkWithEnv0', () {
    test('provides env only', () {
      String? receivedEnv;

      final List<void Function()> buffer = [];
      void flush() {
        for (final fn in buffer) {
          fn();
        }
        buffer.clear();
      }

      Cont.of<String, int>(42)
          .thenForkWithEnv0((env) {
            return Cont.fromRun<String, ()>((
              runtime,
              observer,
            ) {
              buffer.add(() {
                receivedEnv = env;
                observer.onValue(());
              });
            });
          })
          .run('hello');

      flush();
      expect(receivedEnv, 'hello');
    });

    test('preserves original value', () {
      int? value;

      Cont.of<String, int>(42)
          .thenForkWithEnv0((env) => Cont.of('side: $env'))
          .run('hello', onValue: (val) => value = val);

      expect(value, 42);
    });

    test(
      'behaves like thenForkWithEnv with ignored value',
      () {
        int? value1;
        int? value2;

        final cont1 = Cont.of<String, int>(
          42,
        ).thenForkWithEnv0((env) => Cont.of('side: $env'));
        final cont2 = Cont.of<String, int>(42)
            .thenForkWithEnv(
              (env, _) => Cont.of('side: $env'),
            );

        cont1.run('hello', onValue: (val) => value1 = val);
        cont2.run('hello', onValue: (val) => value2 = val);

        expect(value1, value2);
      },
    );
  });
}
