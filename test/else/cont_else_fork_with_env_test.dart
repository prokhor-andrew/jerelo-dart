import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.elseForkWithEnv', () {
    test('propagates original termination', () {
      List<ContError>? errors;

      Cont.stop<String, int>([
            ContError.capture('original'),
          ])
          .elseForkWithEnv(
            (env, e) => Cont.of<String, int>(0),
          )
          .run('hello', onElse: (e) => errors = e);

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

      Cont.stop<String, int>([ContError.capture('err1')])
          .elseForkWithEnv((env, errors) {
            return Cont.fromRun<String, int>((
              runtime,
              observer,
            ) {
              buffer.add(() {
                receivedEnv = env;
                receivedErrors = errors;
                observer.onThen(0);
              });
            });
          })
          .run('hello', onElse: (_) {});

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

      Cont.stop<String, int>([ContError.capture('err')])
          .elseForkWithEnv((env, errors) {
            return Cont.fromRun<String, int>((
              runtime,
              observer,
            ) {
              buffer.add(() {
                order.add('fork');
                observer.onThen(0);
              });
            });
          })
          .run('hello', onElse: (e) => order.add('main'));

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
          .run('hello', onThen: (val) => value = val);

      expect(called, false);
      expect(value, 42);
    });

    test('receives defensive copy of errors', () {
      final originalErrors = [ContError.capture('err1')];
      List<ContError>? receivedErrors;

      final List<void Function()> buffer = [];
      void flush() {
        for (final fn in buffer) {
          fn();
        }
        buffer.clear();
      }

      Cont.stop<String, int>(originalErrors)
          .elseForkWithEnv((env, errors) {
            return Cont.fromRun<String, int>((
              runtime,
              observer,
            ) {
              buffer.add(() {
                receivedErrors = errors;
                errors.add(ContError.capture('err2'));
                observer.onThen(0);
              });
            });
          })
          .run('hello', onElse: (_) {});

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

      final cont = Cont.stop<String, int>().elseForkWithEnv(
        (env, errors) {
          return Cont.fromRun<String, int>((
            runtime,
            observer,
          ) {
            buffer.add(() {
              forkCount++;
              observer.onThen(0);
            });
          });
        },
      );

      cont.run('hello', onElse: (_) {});
      expect(forkCount, 0);
      flush();
      expect(forkCount, 1);

      cont.run('world', onElse: (_) {});
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

      Cont.stop<String, int>()
          .elseForkWithEnv0((env) {
            return Cont.fromRun<String, int>((
              runtime,
              observer,
            ) {
              buffer.add(() {
                receivedEnv = env;
                observer.onThen(0);
              });
            });
          })
          .run('hello', onElse: (_) {});

      flush();
      expect(receivedEnv, 'hello');
    });

    test('propagates original termination', () {
      List<ContError>? errors;

      Cont.stop<String, int>([
            ContError.capture('original'),
          ])
          .elseForkWithEnv0(
            (env) => Cont.of<String, int>(0),
          )
          .run('hello', onElse: (e) => errors = e);

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

        final cont1 = Cont.stop<String, int>()
            .elseForkWithEnv0((env) {
              return Cont.fromRun<String, int>((
                runtime,
                observer,
              ) {
                buffer.add(() {
                  count1++;
                  observer.onThen(0);
                });
              });
            });

        final cont2 = Cont.stop<String, int>()
            .elseForkWithEnv((env, _) {
              return Cont.fromRun<String, int>((
                runtime,
                observer,
              ) {
                buffer.add(() {
                  count2++;
                  observer.onThen(0);
                });
              });
            });

        cont1.run('hello', onElse: (_) {});
        cont2.run('hello', onElse: (_) {});

        expect(count1, 0);
        expect(count2, 0);

        flush();
        expect(count1, 1);
        expect(count2, 1);
      },
    );
  });
}
