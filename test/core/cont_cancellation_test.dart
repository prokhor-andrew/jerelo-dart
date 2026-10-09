import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

/// A continuation that never reports on its own. Its observer is kept so a
/// test can report later, for example after cancellation.
final class Pending<A> {
  ContObserver<A>? observer;

  late final Cont<(), A> cont = Cont.fromRun(
    (runtime, observer) {
      this.observer = observer;
    },
  );
}

void main() {
  group('ContRuntime.onCancel', () {
    test('runs callbacks on cancel in reverse order', () {
      final log = <String>[];

      final token = Cont.fromRun<(), int>(
        (runtime, observer) {
          runtime.onCancel(() => log.add('first'));
          runtime.onCancel(() => log.add('second'));
        },
      ).run(());

      expect(log, isEmpty);
      token.cancel();
      expect(log, equals(['second', 'first']));
    });

    test('runs each callback once', () {
      var count = 0;

      final token = Cont.fromRun<(), int>(
        (runtime, observer) {
          runtime.onCancel(() => count++);
        },
      ).run(());

      token.cancel();
      token.cancel();
      expect(count, equals(1));
    });

    test('unregistered callback does not run', () {
      var called = false;

      final token = Cont.fromRun<(), int>(
        (runtime, observer) {
          final unregister =
              runtime.onCancel(() => called = true);
          unregister();
        },
      ).run(());

      token.cancel();
      expect(called, isFalse);
    });

    test('runs immediately when already cancelled', () {
      ContRuntime<()>? captured;
      var called = false;

      final token = Cont.fromRun<(), int>(
        (runtime, observer) {
          captured = runtime;
        },
      ).run(());

      token.cancel();
      captured!.onCancel(() => called = true);

      expect(called, isTrue);
    });

    test('a throwing callback goes to the onPanic of run',
        () {
      final panics = <Object>[];
      final log = <String>[];

      final token = Cont.fromRun<(), int>(
        (runtime, observer) {
          runtime.onCancel(() => log.add('first'));
          runtime.onCancel(() => throw 'boom');
        },
      ).run((),
          onPanic: (error) => panics.add(error.error));

      token.cancel();

      expect(panics, equals(['boom']));
      expect(log, equals(['first']));
    });
  });

  group('ContRuntime.withCancellation', () {
    test('cancel runs the child callbacks only', () {
      final log = <String>[];
      late void Function() cancelChild;

      final token = Cont.fromRun<(), int>(
        (runtime, observer) {
          runtime.onCancel(() => log.add('parent'));
          final child = runtime.withCancellation();
          child.runtime.onCancel(() => log.add('child'));
          cancelChild = child.cancel;
        },
      ).run(());

      cancelChild();
      expect(log, equals(['child']));

      token.cancel();
      expect(log, equals(['child', 'parent']));
    });

    test('parent cancellation cancels the child', () {
      late ContRuntime<()> childRuntime;

      final token = Cont.fromRun<(), int>(
        (runtime, observer) {
          childRuntime = runtime.withCancellation().runtime;
        },
      ).run(());

      expect(childRuntime.isCancelled(), isFalse);
      token.cancel();
      expect(childRuntime.isCancelled(), isTrue);
    });
  });

  group('Cont.bracket cancellation', () {
    late List<String> log;

    Cont<(), ()> release(String resource) {
      return Cont.fromRun((runtime, observer) {
        log.add('release $resource');
        observer.onThen(());
      });
    }

    setUp(() => log = []);

    test('releases on cancel while use is silent', () {
      final use = Pending<int>();
      var delivered = false;

      final token = Cont.bracket<(), String, int>(
        acquire: Cont.of('r'),
        release: release,
        use: (_) => use.cont,
      ).run(
        (),
        onThen: (_) => delivered = true,
        onElse: (_) => delivered = true,
      );

      expect(log, isEmpty);
      token.cancel();
      expect(log, equals(['release r']));
      expect(delivered, isFalse);
    });

    test('releases once when use reports after cancel', () {
      final use = Pending<int>();
      var delivered = false;

      final token = Cont.bracket<(), String, int>(
        acquire: Cont.of('r'),
        release: release,
        use: (_) => use.cont,
      ).run((), onThen: (_) => delivered = true);

      token.cancel();
      use.observer!.onThen(1);

      expect(log, equals(['release r']));
      expect(delivered, isFalse);
    });

    test('releases once on normal completion', () {
      final use = Pending<int>();
      int? result;

      final token = Cont.bracket<(), String, int>(
        acquire: Cont.of('r'),
        release: release,
        use: (_) => use.cont,
      ).run((), onThen: (v) => result = v);

      use.observer!.onThen(1);
      token.cancel();

      expect(result, equals(1));
      expect(log, equals(['release r']));
    });

    test('releases a resource acquired after cancel', () {
      final acquire = Pending<String>();
      var useStarted = false;
      var delivered = false;

      final token = Cont.bracket<(), String, int>(
        acquire: acquire.cont,
        release: release,
        use: (_) {
          useStarted = true;
          return Cont.of(1);
        },
      ).run((), onThen: (_) => delivered = true);

      token.cancel();
      expect(log, isEmpty);

      acquire.observer!.onThen('r');

      expect(log, equals(['release r']));
      expect(useStarted, isFalse);
      expect(delivered, isFalse);
    });

    test('nested brackets release inner first on cancel',
        () {
      final use = Pending<int>();

      final token = Cont.bracket<(), String, int>(
        acquire: Cont.of('outer'),
        release: release,
        use: (_) => Cont.bracket<(), String, int>(
          acquire: Cont.of('inner'),
          release: release,
          use: (_) => use.cont,
        ),
      ).run(());

      token.cancel();
      expect(
          log, equals(['release inner', 'release outer']));
    });

    test('releases on the losing side of either quitFast',
        () {
      final use = Pending<int>();
      int? result;

      Cont.either<(), int>(
        Cont.bracket<(), String, int>(
          acquire: Cont.of('r'),
          release: release,
          use: (_) => use.cont,
        ),
        Cont.of(2),
        policy: ContEitherPolicy.quitFast<int>(),
      ).run((), onThen: (v) => result = v);

      expect(result, equals(2));
      expect(log, equals(['release r']));
    });

    test('releases on the losing side of all quitFast', () {
      final use = Pending<int>();
      List<ContError>? errors;

      Cont.all<(), int>(
        [
          Cont.bracket<(), String, int>(
            acquire: Cont.of('r'),
            release: release,
            use: (_) => use.cont,
          ),
          Cont.stop<(), int>(),
        ],
        policy: ContBothPolicy.quitFast(),
      ).run((), onElse: (e) => errors = e);

      expect(errors, isEmpty);
      expect(log, equals(['release r']));
    });

    test('releases when a child scope is cancelled', () {
      final use = Pending<int>();

      Cont.bracket<(), String, int>(
        acquire: Cont.of('r'),
        release: release,
        use: (_) => use.cont,
      ).decor((run, runtime, observer) {
        final deadline = runtime.withCancellation();
        run(deadline.runtime, observer);

        // the deadline passes
        deadline.cancel();
      }).run(());

      expect(log, equals(['release r']));
    });
  });

  group('Forks and cancellation', () {
    test('a fork is cancelled with its parent', () {
      var forkCancelled = false;

      final token = Cont.of<(), int>(1)
          .thenFork(
        (_) => Cont.fromRun<(), int>(
          (runtime, observer) {
            runtime.onCancel(() => forkCancelled = true);
          },
        ),
      )
          .run(());

      token.cancel();

      expect(forkCancelled, isTrue);
    });
  });
}
