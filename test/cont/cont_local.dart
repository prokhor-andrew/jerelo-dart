import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.local', () {
    test('transforms environment', () {
      int? receivedEnv;

      Cont.fromRun<int, ()>((runtime, observer) {
        receivedEnv = runtime.env();
        observer.onValue(());
      }).local<String>((str) => str.length).run('hello');

      expect(receivedEnv, 5);
    });

    test('preserves value', () {
      int? value;

      Cont.of<int, int>(42)
          .local<String>((str) => str.length)
          .run('hello', onValue: (val) => value = val);

      expect(value, 42);
    });

    test('preserves termination', () {
      List<ContError>? errors;

      Cont.terminate<int, int>([ContError.capture('err')])
          .local<String>((str) => str.length)
          .run('hello', onTerminate: (e) => errors = e);

      expect(errors!.length, 1);
      expect(errors![0].error, 'err');
    });

    test('works with Cont.ask', () {
      String? value;

      Cont.ask<int>()
          .map((n) => 'number: $n')
          .local<String>((str) => str.length)
          .run('hello', onValue: (val) => value = val);

      expect(value, 'number: 5');
    });

    test('terminates when transformation throws', () {
      final cont = Cont.of<int, int>(42).local<String>((
        str,
      ) {
        throw 'Transform Error';
      });

      ContError? error;
      cont.run(
        'hello',
        onTerminate: (errors) => error = errors.first,
      );

      expect(error!.error, 'Transform Error');
    });

    test('supports chaining', () {
      int? receivedEnv;

      Cont.fromRun<int, ()>((runtime, observer) {
            receivedEnv = runtime.env();
            observer.onValue(());
          })
          .local<String>((str) => str.length)
          .local<List<int>>((list) => list.first.toString())
          .run([10, 20, 30]);

      expect(receivedEnv, 2); // "10".length
    });

    test('supports multiple runs', () {
      var callCount = 0;
      final cont = Cont.fromRun<int, ()>((
        runtime,
        observer,
      ) {
        callCount++;
        observer.onValue(());
      }).local<String>((str) => str.length);

      cont.run('test');
      expect(callCount, 1);

      cont.run('hello');
      expect(callCount, 2);
    });

    test('never calls onPanic', () {
      Cont.of<int, int>(42)
          .local<String>((str) => str.length)
          .run(
            'hello',
            onPanic: (_) => fail('Should not be called'),
            onValue: (_) {},
          );
    });

    test('prevents execution after cancellation', () {
      bool executed = false;

      final List<void Function()> buffer = [];
      void flush() {
        for (final fn in buffer) {
          fn();
        }
        buffer.clear();
      }

      final cont = Cont.fromRun<int, int>((
        runtime,
        observer,
      ) {
        buffer.add(() {
          if (runtime.isCancelled()) return;
          executed = true;
          observer.onValue(10);
        });
      }).local<String>((str) => str.length);

      final token = cont.run('hello');
      token.cancel();
      flush();

      expect(executed, false);
    });

    test('local0 ignores outer environment', () {
      int? receivedEnv;

      Cont.fromRun<int, ()>((runtime, observer) {
        receivedEnv = runtime.env();
        observer.onValue(());
      }).local0<String>(() => 42).run('ignored');

      expect(receivedEnv, 42);
    });

    test(
      'local0 differs from local in parameter usage',
      () {
        int? env1;
        int? env2;

        final cont1 = Cont.fromRun<int, ()>((
          runtime,
          observer,
        ) {
          env1 = runtime.env();
          observer.onValue(());
        }).local0<String>(() => 99);

        final cont2 = Cont.fromRun<int, ()>((
          runtime,
          observer,
        ) {
          env2 = runtime.env();
          observer.onValue(());
        }).local<String>((_) => 99);

        cont1.run('test');
        cont2.run('test');

        expect(env1, 99);
        expect(env2, 99);
      },
    );

    test('scope provides fixed environment', () {
      int? receivedEnv;

      Cont.fromRun<int, ()>((runtime, observer) {
        receivedEnv = runtime.env();
        observer.onValue(());
      }).scope<String>(100).run('ignored');

      expect(receivedEnv, 100);
    });

    test('scope differs from local0 in eagerness', () {
      int? env1;
      int? env2;

      final cont1 = Cont.fromRun<int, ()>((
        runtime,
        observer,
      ) {
        env1 = runtime.env();
        observer.onValue(());
      }).scope<String>(100);

      final cont2 = Cont.fromRun<int, ()>((
        runtime,
        observer,
      ) {
        env2 = runtime.env();
        observer.onValue(());
      }).local0<String>(() => 100);

      cont1.run('test');
      cont2.run('test');

      expect(env1, 100);
      expect(env2, 100);
    });

    test('scope supports null environment', () {
      int? receivedEnv;

      Cont.fromRun<int?, ()>((runtime, observer) {
        receivedEnv = runtime.env();
        observer.onValue(());
      }).scope<String>(null).run('ignored');

      expect(receivedEnv, null);
    });

    test('scope preserves environment identity', () {
      final env = [1, 2, 3];
      Object? receivedEnv;

      Cont.fromRun<List<int>, ()>((runtime, observer) {
        receivedEnv = runtime.env();
        observer.onValue(());
      }).scope<String>(env).run('ignored');

      expect(identical(env, receivedEnv), isTrue);
    });

    test('works in thenDo chain', () {
      int? value;

      Cont.ask<int>()
          .thenDo((n) => Cont.of(n * 2))
          .local<String>((str) => str.length)
          .run('test', onValue: (val) => value = val);

      expect(value, 8); // "test".length = 4, 4 * 2 = 8
    });

    test('provides environment isolation', () {
      final envs = <int>[];

      final inner = Cont.fromRun<int, ()>((
        runtime,
        observer,
      ) {
        envs.add(runtime.env());
        observer.onValue(());
      });

      final outer = inner
          .local<int>((n) => n * 2)
          .thenDo((_) => inner.local<int>((n) => n * 3));

      outer.run(5);

      expect(envs, [10, 15]); // 5*2=10, 5*3=15
    });
  });
}
