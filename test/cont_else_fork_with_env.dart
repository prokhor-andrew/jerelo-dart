import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.elseForkWithEnv', () {
    test('propagates original termination', () {
      List<ContError>? errors;

      Cont.terminate<String, int>([
            ContError.capture('original'),
          ])
          .elseForkWithEnv(
            (env, e) => Cont.of<String, int>(0),
          )
          .run('hello', onTerminate: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'original');
    });

    test('provides env and errors to fork', () {
      String? receivedEnv;
      List<ContError>? receivedErrors;

      final List<void Function()> buffer = [];
      void flush() {
        for (final fn in buffer) {
          fn();
        }
        buffer.clear();
      }

      Cont.terminate<String, int>([
            ContError.capture('err1'),
          ])
          .elseForkWithEnv((env, errors) {
            return Cont.fromRun<String, int>((
              runtime,
              observer,
            ) {
              buffer.add(() {
                receivedEnv = env;
                receivedErrors = errors;
                observer.onValue(0);
              });
            });
          })
          .run('hello', onTerminate: (_) {});

      expect(receivedEnv, null);
      flush();
      expect(receivedEnv, 'hello');
      expect(receivedErrors!.length, 1);
      expect(receivedErrors![0].error, 'err1');
    });

    test('executes without waiting', () {
      final order = <String>[];

      final List<void Function()> buffer = [];
      void flush() {
        for (final fn in buffer) {
          fn();
        }
        buffer.clear();
      }

      Cont.terminate<String, int>([
            ContError.capture('err'),
          ])
          .elseForkWithEnv((env, errors) {
            return Cont.fromRun<String, int>((
              runtime,
              observer,
            ) {
              buffer.add(() {
                order.add('fork');
                observer.onValue(0);
              });
            });
          })
          .run(
            'hello',
            onTerminate: (e) => order.add('main'),
          );

      expect(order, ['main']);
      flush();
      expect(order, ['main', 'fork']);
    });

    test('never executes on value path', () {
      bool called = false;
      int? value;

      Cont.of<String, int>(42)
          .elseForkWithEnv((env, errors) {
            called = true;
            return Cont.of(0);
          })
          .run('hello', onValue: (val) => value = val);

      expect(called, false);
      expect(value, 42);
    });

    test('receives defensive copy of errors', () {
      final originalErrors = [
        ContError.capture('err1'),
      ];
      List<ContError>? receivedErrors;

      final List<void Function()> buffer = [];
      void flush() {
        for (final fn in buffer) {
          fn();
        }
        buffer.clear();
      }

      Cont.terminate<String, int>(originalErrors)
          .elseForkWithEnv((env, errors) {
            return Cont.fromRun<String, int>((
              runtime,
              observer,
            ) {
              buffer.add(() {
                receivedErrors = errors;
                errors.add(ContError.capture('err2'));
                observer.onValue(0);
              });
            });
          })
          .run('hello', onTerminate: (_) {});

      flush();
      expect(originalErrors.length, 1);
      expect(receivedErrors!.length, 2);
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

      final cont = Cont.terminate<String, int>()
          .elseForkWithEnv((env, errors) {
        return Cont.fromRun<String, int>((
          runtime,
          observer,
        ) {
          buffer.add(() {
            forkCount++;
            observer.onValue(0);
          });
        });
      });

      cont.run('hello', onTerminate: (_) {});
      expect(forkCount, 0);
      flush();
      expect(forkCount, 1);

      cont.run('world', onTerminate: (_) {});
      expect(forkCount, 1);
      flush();
      expect(forkCount, 2);
    });
  });

  group('Cont.elseForkWithEnv0', () {
    test('provides env only', () {
      String? receivedEnv;

      final List<void Function()> buffer = [];
      void flush() {
        for (final fn in buffer) {
          fn();
        }
        buffer.clear();
      }

      Cont.terminate<String, int>()
          .elseForkWithEnv0((env) {
            return Cont.fromRun<String, int>((
              runtime,
              observer,
            ) {
              buffer.add(() {
                receivedEnv = env;
                observer.onValue(0);
              });
            });
          })
          .run('hello', onTerminate: (_) {});

      flush();
      expect(receivedEnv, 'hello');
    });

    test('propagates original termination', () {
      List<ContError>? errors;

      Cont.terminate<String, int>([
            ContError.capture('original'),
          ])
          .elseForkWithEnv0(
            (env) => Cont.of<String, int>(0),
          )
          .run('hello', onTerminate: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'original');
    });

    test(
      'behaves like elseForkWithEnv with ignored errors',
      () {
        var count1 = 0;
        var count2 = 0;

        final List<void Function()> buffer = [];
        void flush() {
          for (final fn in buffer) {
            fn();
          }
          buffer.clear();
        }

        final cont1 = Cont.terminate<String, int>()
            .elseForkWithEnv0((env) {
          return Cont.fromRun<String, int>((
            runtime,
            observer,
          ) {
            buffer.add(() {
              count1++;
              observer.onValue(0);
            });
          });
        });

        final cont2 = Cont.terminate<String, int>()
            .elseForkWithEnv((env, _) {
          return Cont.fromRun<String, int>((
            runtime,
            observer,
          ) {
            buffer.add(() {
              count2++;
              observer.onValue(0);
            });
          });
        });

        cont1.run('hello', onTerminate: (_) {});
        cont2.run('hello', onTerminate: (_) {});

        expect(count1, 0);
        expect(count2, 0);

        flush();
        expect(count1, 1);
        expect(count2, 1);
      },
    );
  });
}
