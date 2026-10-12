import 'dart:async';

import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

NormalCrash crashOf(Object error) {
  return ContCrash.tryCatch<void>(() {
    throw error;
  }).match(
    (_) => throw StateError('expected a crash'),
    (crash) => crash,
  );
}

/// A continuation that never reports on its own. Its observer is kept so a
/// test can report later, for example after cancellation.
final class Pending<A> {
  SafeObserver<String, A>? observer;

  late final Cont<(), String, A> cont = Cont.fromRun(
    (runtime, observer) {
      this.observer = observer;
    },
  );
}

void main() {
  group('ContRuntime.onCancel', () {
    test('runs callbacks on cancel in reverse order', () {
      final log = <String>[];

      final token = Cont.fromRun<(), String, int>(
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

      final token = Cont.fromRun<(), String, int>(
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

      final token = Cont.fromRun<(), String, int>(
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

      final token = Cont.fromRun<(), String, int>(
        (runtime, observer) {
          captured = runtime;
        },
      ).run(());

      token.cancel();
      captured!.onCancel(() => called = true);

      expect(called, isTrue);
    });

    test(
        'a throwing callback is reported and others still run',
        () async {
      final errors = <Object>[];
      final log = <String>[];

      await runZonedGuarded(() async {
        final token = Cont.fromRun<(), String, int>(
          (runtime, observer) {
            runtime.onCancel(() => log.add('first'));
            runtime.onCancel(() => throw 'boom');
          },
        ).run(());

        token.cancel();
        await Future<void>.delayed(Duration.zero);
      }, (error, _) => errors.add(error));

      expect(log, equals(['first']));
      expect(errors, equals(['boom']));
    });
  });

  group('ContRuntime.withCancellation', () {
    test('cancel runs the child callbacks only', () {
      final log = <String>[];
      late void Function() cancelChild;

      final token = Cont.fromRun<(), String, int>(
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
      final log = <String>[];
      late ContRuntime<()> childRuntime;

      final token = Cont.fromRun<(), String, int>(
        (runtime, observer) {
          final child = runtime.withCancellation();
          childRuntime = child.runtime;
          childRuntime.onCancel(() => log.add('child'));
        },
      ).run(());

      expect(childRuntime.isCancelled(), isFalse);
      token.cancel();
      expect(childRuntime.isCancelled(), isTrue);
      expect(log, equals(['child']));
    });

  });

  group('onCancel panics', () {
    test('a throwing callback goes to the onPanic of run',
        () {
      final panics = <Object>[];
      final log = <String>[];

      final token = Cont.fromRun<(), String, int>(
        (runtime, observer) {
          runtime.onCancel(() => log.add('first'));
          runtime.onCancel(() => throw 'boom');
        },
      ).run((),
          onPanic: (crash) => panics.add(crash.error));

      token.cancel();

      expect(panics, equals(['boom']));
      expect(log, equals(['first']));
    });
  });

  group('Results after cancel', () {
    final Map<
        String,
        Cont<(), String, int> Function(
            Cont<(), String, int>)> operators = {
      'run': (c) => c,
      'thenMap': (c) => c.thenMap((v) => v + 1),
      'elseMap': (c) => c.elseMap((e) => e),
      'crashDo': (c) =>
          c.crashDo((crash) => Cont.crash(crash)),
    };

    for (final MapEntry(key: name, value: operator)
        in operators.entries) {
      for (final channel in ['then', 'else', 'crash']) {
        test('$name drops a late $channel', () {
          final pending = Pending<int>();
          var delivered = false;

          final token = operator(pending.cont).run(
            (),
            onThen: (_) => delivered = true,
            onElse: (_) => delivered = true,
            onCrash: (_) => delivered = true,
          );
          token.cancel();

          switch (channel) {
            case 'then':
              pending.observer!.onThen(1);
            case 'else':
              pending.observer!.onElse('late');
            default:
              pending.observer!.onCrash(crashOf('late'));
          }

          expect(delivered, isFalse);
        });
      }
    }
  });

}
