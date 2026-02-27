import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.decorate', () {
    test('forwards value when f delegates to run', () {
      int? result;

      Cont.of<(), String, int>(42)
          .decorate((run, runtime, observer) {
        run(runtime, observer);
      }).run((), onThen: (v) => result = v);

      expect(result, equals(42));
    });

    test('forwards error when f delegates to run', () {
      String? error;

      Cont.error<(), String, int>('oops')
          .decorate((run, runtime, observer) {
        run(runtime, observer);
      }).run((), onElse: (e) => error = e);

      expect(error, equals('oops'));
    });

    test('can block execution by not calling run', () {
      bool ran = false;
      bool thenCalled = false;

      Cont.fromRun<(), String, int>((runtime, observer) {
        ran = true;
        observer.onThen(42);
      }).decorate((run, runtime, observer) {
        // Don't call run
      }).run((), onThen: (_) => thenCalled = true);

      expect(ran, isFalse);
      expect(thenCalled, isFalse);
    });

    test('can add behavior before run', () {
      final log = <String>[];

      Cont.of<(), String, int>(42)
          .decorate((run, runtime, observer) {
        log.add('before');
        run(runtime, observer);
      }).run((), onThen: (_) => log.add('then'));

      expect(log, equals(['before', 'then']));
    });

    test('can add behavior after run', () {
      final log = <String>[];

      Cont.of<(), String, int>(42)
          .decorate((run, runtime, observer) {
        run(runtime, observer);
        log.add('after');
      }).run((), onThen: (_) => log.add('then'));

      expect(log, equals(['then', 'after']));
    });

    test('identity preserves value', () {
      int? result;

      Cont.of<(), String, int>(42)
          .decorate((run, runtime, observer) =>
              run(runtime, observer))
          .run((), onThen: (v) => result = v);

      expect(result, equals(42));
    });

    test('identity preserves error', () {
      String? error;

      Cont.error<(), String, int>('oops')
          .decorate((run, runtime, observer) =>
              run(runtime, observer))
          .run((), onElse: (e) => error = e);

      expect(error, equals('oops'));
    });

    test('can be run multiple times', () {
      int? first;
      int? second;

      final cont = Cont.of<(), String, int>(42).decorate(
          (run, runtime, observer) =>
              run(runtime, observer));

      cont.run((), onThen: (v) => first = v);
      cont.run((), onThen: (v) => second = v);

      expect(first, equals(42));
      expect(second, equals(42));
    });

    test('does not call onPanic', () {
      bool panicCalled = false;

      Cont.of<(), String, int>(42)
          .decorate((run, runtime, observer) =>
              run(runtime, observer))
          .run(
        (),
        onPanic: (_) => panicCalled = true,
      );

      expect(panicCalled, isFalse);
    });

    test('does not call onElse on value path', () {
      bool elseCalled = false;

      Cont.of<(), String, int>(42)
          .decorate((run, runtime, observer) =>
              run(runtime, observer))
          .run(
        (),
        onElse: (_) => elseCalled = true,
      );

      expect(elseCalled, isFalse);
    });

    test('preserves environment', () {
      String? capturedEnv;

      Cont.askThen<String, Never>()
          .decorate((run, runtime, observer) {
        capturedEnv = runtime.env();
        run(runtime, observer);
      }).run('myEnv');

      expect(capturedEnv, equals('myEnv'));
    });

    test('cancellation prevents execution', () async {
      bool ran = false;

      final cont = Cont.fromRun<(), String, int>(
          (runtime, observer) {
        ran = true;
        observer.onThen(42);
      }).decorate((run, runtime, observer) {
        Future.microtask(() => run(runtime, observer));
      });

      final token = cont.run(());
      token.cancel();

      await Future.delayed(Duration.zero);

      expect(ran, isFalse);
    });

    test('calling run twice is idempotent', () {
      int thenCallCount = 0;

      Cont.of<(), String, int>(42)
          .decorate((run, runtime, observer) {
        run(runtime, observer);
        run(runtime, observer);
      }).run((), onThen: (_) => thenCallCount++);

      expect(thenCallCount, equals(1));
    });

    test('can replace observer onThen', () {
      int? result;

      Cont.of<(), String, int>(42)
          .decorate((run, runtime, observer) {
        run(
            runtime,
            observer
                .copyUpdateOnThen((v) => result = v * 2));
      }).run((), onThen: (_) => result = -1);

      expect(result, equals(84));
    });

    test('can replace observer onElse', () {
      String? captured;

      Cont.error<(), String, int>('original')
          .decorate((run, runtime, observer) {
        run(
          runtime,
          observer.copyUpdateOnElse<String>(
            (e) => captured = 'intercepted:$e',
          ),
        );
      }).run((), onElse: (e) => captured = e);

      expect(captured, equals('intercepted:original'));
    });

    test('chaining composes correctly', () {
      final log = <String>[];

      Cont.of<(), String, int>(42)
          .decorate((run, runtime, observer) {
        log.add('outer-before');
        run(runtime, observer);
        log.add('outer-after');
      }).decorate((run, runtime, observer) {
        log.add('inner-before');
        run(runtime, observer);
        log.add('inner-after');
      }).run((), onThen: (_) => log.add('then'));

      expect(
        log,
        equals([
          'inner-before',
          'outer-before',
          'then',
          'outer-after',
          'inner-after',
        ]),
      );
    });
  });
}
