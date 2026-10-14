import 'dart:async';

import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

const depth = 1000000;

NormalCrash crashOf(Object error) {
  return ContCrash.tryCatch<void>(() {
    throw error;
  }).match(
    (_) => throw StateError('expected a crash'),
    (crash) => crash,
  );
}

/// Runs [cont] and returns its outcome as a string.
String outcomeOf<F, A>(Cont<(), F, A> cont) {
  var outcome = 'nothing';
  cont.run(
    (),
    onThen: (v) => outcome = 'then $v',
    onElse: (e) => outcome = 'else $e',
    onCrash: (c) => outcome = 'crash $c',
  );
  return outcome;
}

void main() {
  group('deep synchronous chains', () {
    test('left-nested thenDo', () {
      Cont<(), String, int> cont = Cont.of(0);
      for (var i = 0; i < depth; i++) {
        cont = cont.thenDo((x) => Cont.of(x + 1));
      }

      expect(outcomeOf(cont), equals('then $depth'));
    });

    test('right-nested thenDo', () {
      Cont<(), String, int> count(int i) {
        return i == depth
            ? Cont.of(i)
            : Cont.of<(), String, int>(i)
                .thenDo((x) => count(x + 1));
      }

      expect(outcomeOf(count(0)), equals('then $depth'));
    });

    test('left-nested elseDo', () {
      Cont<(), int, int> cont = Cont.error(0);
      for (var i = 0; i < depth; i++) {
        cont = cont.elseDo((e) => Cont.error(e + 1));
      }

      expect(outcomeOf(cont), equals('else $depth'));
    });

    test('right-nested elseDo', () {
      Cont<(), int, int> count(int i) {
        return i == depth
            ? Cont.error(i)
            : Cont.error<(), int, int>(i)
                .elseDo((e) => count(e + 1));
      }

      expect(outcomeOf(count(0)), equals('else $depth'));
    });

    test('left-nested crashDo', () {
      var handled = 0;
      Cont<(), String, int> cont = Cont.crash(crashOf('c'));
      for (var i = 0; i < depth; i++) {
        cont = cont.crashDo((c) {
          handled++;
          return Cont.crash(c);
        });
      }
      cont = cont.crashDo((_) => Cont.of(handled));

      expect(outcomeOf(cont), equals('then $depth'));
    });

    test('a value passes a deep stack of else frames', () {
      Cont<(), String, int> cont = Cont.of(1);
      for (var i = 0; i < depth; i++) {
        cont = cont.elseDo((e) => Cont.error(e));
      }

      expect(outcomeOf(cont), equals('then 1'));
    });

    test('thenMap and alternating channels', () {
      Cont<(), String, int> cont = Cont.of(0);
      for (var i = 0; i < depth ~/ 2; i++) {
        cont = cont
            .thenMap((x) => x + 1)
            .elseDo((e) => Cont.error(e));
      }

      expect(outcomeOf(cont), equals('then ${depth ~/ 2}'));
    });

    test('a deep chain inside a combinator', () {
      Cont<(), String, int> chain = Cont.of(0);
      for (var i = 0; i < depth; i++) {
        chain = chain.thenMap((x) => x + 1);
      }

      expect(
        outcomeOf(Cont.all([chain, chain],
            policy: OkPolicy.quitFast())),
        equals('then [$depth, $depth]'),
      );
    });
  });

  group('fromDeferred and local', () {
    test('recursion through fromDeferred', () {
      Cont<(), String, int> count(int i) {
        return i == depth
            ? Cont.of(i)
            : Cont.fromDeferred(() => count(i + 1));
      }

      expect(outcomeOf(count(0)), equals('then $depth'));
    });

    test('left-nested local', () {
      Cont<int, String, int> cont = Cont.askThen();
      for (var i = 0; i < depth; i++) {
        cont = cont.local((e) => e + 1);
      }

      int? result;
      cont.run(0, onThen: (v) => result = v);
      expect(result, equals(depth));
    });

    test('local restores the environment after its source',
        () {
      final envs = <int>[];
      Cont.askThen<int, String>()
          .thenTap((e) {
            envs.add(e);
            return Cont.of(());
          })
          .local<int>((e) => e * 10)
          .thenDo((_) => Cont.askThen<int, String>())
          .run(1, onThen: envs.add);

      expect(envs, equals([10, 1]));
    });

    test(
        'local restores the environment after an async step',
        () async {
      final completer = Completer<List<int>>();
      final envs = <int>[];
      Cont.askThen<int, String>()
          .thenDo((e) {
            envs.add(e);
            return Cont.fromRun<int, String, int>((env, o) {
              Timer(
                  Duration.zero, () => o.onThen(env.env()));
            });
          })
          .thenTap((e) {
            envs.add(e);
            return Cont.of(());
          })
          .local<int>((e) => e * 10)
          .thenDo((_) => Cont.askThen<int, String>())
          .run(1, onThen: (e) {
            envs.add(e);
            completer.complete(envs);
          });

      expect(await completer.future, equals([10, 10, 1]));
    });

    test(
        'a throw from the thunk or from local\'s f is a crash',
        () {
      expect(
        outcomeOf(Cont.fromDeferred<(), String, int>(
            () => throw 'thunk')),
        startsWith('crash NormalCrash { error=thunk'),
      );

      ContCrash? crash;
      Cont.askThen<int, String>()
          .local<int>((_) => throw 'local')
          .run(1, onCrash: (c) => crash = c);
      expect(
          (crash! as NormalCrash).error, equals('local'));
    });
  });

  group('forks', () {
    test('left-nested thenFork, elseFork and crashFork',
        () {
      var forks = 0;
      Cont<(), String, int> cont = Cont.of(0);
      for (var i = 0; i < depth ~/ 3; i++) {
        cont = cont
            .thenFork((_) {
              forks++;
              return Cont.of<(), String, ()>(());
            })
            .elseFork((_) => Cont.of<(), String, ()>(()))
            .crashFork((_) => Cont.of<(), String, ()>(()));
      }

      expect(outcomeOf(cont), equals('then 0'));
      expect(forks, equals(depth ~/ 3));
    });
  });

  group('asynchronous steps', () {
    test(
        'a chain mixing synchronous and asynchronous steps',
        () async {
      Cont<(), String, int> later(int x) {
        return Cont.fromRun((env, observer) {
          Timer(
              Duration.zero, () => observer.onThen(x + 1));
        });
      }

      Cont<(), String, int> cont = Cont.of(0);
      for (var i = 0; i < 10000; i++) {
        cont = i % 1000 == 0
            ? cont.thenDo(later)
            : cont.thenMap((x) => x + 1);
      }

      final completer = Completer<int>();
      cont.run((), onThen: completer.complete);

      expect(await completer.future, equals(10000));
    });
  });

  group('monad laws', () {
    Cont<(), String, int> f(int x) =>
        x.isEven ? Cont.of(x ~/ 2) : Cont.error('odd $x');
    Cont<(), String, int> g(int x) => x > 2
        ? Cont.crash(crashOf('big'))
        : Cont.of(x * 10);

    for (final m in <String, Cont<(), String, int>>{
      'value': Cont.of(4),
      'error': Cont.error('e'),
      'crash': Cont.crash(crashOf('c')),
    }.entries) {
      test('right identity on ${m.key}', () {
        expect(
          outcomeOf(m.value.thenDo(Cont.of)),
          equals(outcomeOf(m.value)),
        );
      });

      test('associativity on ${m.key}', () {
        expect(
          outcomeOf(m.value.thenDo(f).thenDo(g)),
          equals(outcomeOf(
              m.value.thenDo((x) => f(x).thenDo(g)))),
        );
      });
    }

    for (final a in [3, 4, 8]) {
      test('left identity with $a', () {
        expect(
          outcomeOf(Cont.of<(), String, int>(a).thenDo(f)),
          equals(outcomeOf(f(a))),
        );
      });
    }
  });

  group('runs', () {
    test('runs of one Cont are independent', () async {
      final observers = <SafeObserver<String, int>>[];
      final leaf = Cont.fromRun<(), String, int>((env, o) {
        observers.add(o);
      });
      final cont = leaf.thenMap((x) => x * 2);
      final results = <int>[];

      cont.run((), onThen: results.add);
      cont.run((), onThen: results.add);
      observers[1].onThen(5);
      observers[0].onThen(1);

      expect(results, equals([10, 2]));
    });

    test('code after a synchronous report runs first', () {
      final log = <String>[];
      Cont.fromRun<(), String, int>((env, o) {
        o.onThen(1);
        log.add('leaf');
      }).thenDo((x) {
        log.add('next');
        return Cont.of(x);
      }).run(());

      expect(log, equals(['leaf', 'next']));
    });

    test('a throw in a callback is a panic', () {
      NormalCrash? panic;
      Cont.of<(), String, int>(1).thenMap((x) => x + 1).run(
        (),
        onThen: (_) => throw 'callback',
        onPanic: (p) => panic = p,
      );

      expect(panic!.error, equals('callback'));
    });

    test('a throw from f is a crash', () {
      expect(
        outcomeOf(Cont.of<(), String, int>(1)
            .thenDo<int>((_) => throw 'f')),
        startsWith('crash NormalCrash { error=f'),
      );
    });
  });

  group('cancel', () {
    test('a cancel mid-chain stops it without an outcome',
        () {
      final observers = <SafeObserver<String, int>>[];
      final started = <int>[];
      Cont<(), String, int> leaf(int i) {
        return Cont.fromRun((runtime, o) {
          started.add(i);
          observers.add(o);
        });
      }

      var outcomes = 0;
      final token = leaf(0)
          .thenDo((_) => leaf(1))
          .thenDo((_) => leaf(2))
          .run(
        (),
        onThen: (_) => outcomes++,
        onElse: (_) => outcomes++,
        onCrash: (_) => outcomes++,
      );
      observers[0].onThen(0);
      token.cancel();
      observers[1].onThen(1);

      expect(started, equals([0, 1]));
      expect(outcomes, equals(0));
    });
  });
}
