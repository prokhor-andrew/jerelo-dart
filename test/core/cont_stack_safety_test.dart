import 'dart:async';

import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

const depth = 1000000;

/// Runs [cont] and returns its outcome as a string.
String outcomeOf<A>(Cont<(), A> cont) {
  var outcome = 'nothing';
  cont.run(
    (),
    onThen: (v) => outcome = 'then $v',
    onElse: (errors) => outcome =
        'else ${errors.map((e) => e.error).toList()}',
  );
  return outcome;
}

Cont<(), A> stopWith<A>(Object error) {
  return Cont.stop([ContError.withNoStackTrace(error)]);
}

void main() {
  group('deep synchronous chains', () {
    test('left-nested thenDo', () {
      Cont<(), int> cont = Cont.of(0);
      for (var i = 0; i < depth; i++) {
        cont = cont.thenDo((x) => Cont.of(x + 1));
      }

      expect(outcomeOf(cont), equals('then $depth'));
    });

    test('right-nested thenDo', () {
      Cont<(), int> count(int i) {
        return i == depth
            ? Cont.of(i)
            : Cont.of<(), int>(i).thenDo(
                (x) => count(x + 1),
              );
      }

      expect(outcomeOf(count(0)), equals('then $depth'));
    });

    test('left-nested elseDo', () {
      var handled = 0;
      Cont<(), int> cont = stopWith('e');
      for (var i = 0; i < depth; i++) {
        cont = cont.elseDo((errors) {
          handled++;
          return Cont.stop(errors);
        });
      }
      cont = cont.elseDo((_) => Cont.of(handled));

      expect(outcomeOf(cont), equals('then $depth'));
    });

    test('right-nested elseDo', () {
      Cont<(), int> count(int i) {
        return i == depth
            ? Cont.of(i)
            : stopWith<int>(i).elseDo((_) => count(i + 1));
      }

      expect(outcomeOf(count(0)), equals('then $depth'));
    });

    test('a value passes a deep stack of else frames', () {
      Cont<(), int> cont = Cont.of(1);
      for (var i = 0; i < depth; i++) {
        cont = cont.elseDo((errors) => Cont.stop(errors));
      }

      expect(outcomeOf(cont), equals('then 1'));
    });

    test('thenMap and alternating channels', () {
      Cont<(), int> cont = Cont.of(0);
      for (var i = 0; i < depth ~/ 2; i++) {
        cont = cont
            .thenMap((x) => x + 1)
            .elseDo((errors) => Cont.stop(errors));
      }

      expect(outcomeOf(cont), equals('then ${depth ~/ 2}'));
    });

    test('a deep chain inside a combinator', () {
      Cont<(), int> chain = Cont.of(0);
      for (var i = 0; i < depth; i++) {
        chain = chain.thenMap((x) => x + 1);
      }

      expect(
        outcomeOf(
          Cont.all([
            chain,
            chain,
          ], policy: ContBothPolicy.quitFast()),
        ),
        equals('then [$depth, $depth]'),
      );
    });

    test('left-nested forks, elseTap and elseZip', () {
      var forks = 0;
      Cont<(), int> cont = Cont.of(0);
      for (var i = 0; i < depth ~/ 4; i++) {
        cont = cont
            .thenFork((_) {
              forks++;
              return Cont.of<(), ()>(());
            })
            .elseFork((_) => Cont.of<(), ()>(()))
            .elseTap((errors) => Cont.stop(errors))
            .elseZip((errors) => Cont.stop([]));
      }

      expect(outcomeOf(cont), equals('then 0'));
      expect(forks, equals(depth ~/ 4));
    });
  });

  group('fromDeferred and local', () {
    test('recursion through fromDeferred', () {
      Cont<(), int> count(int i) {
        return i == depth
            ? Cont.of(i)
            : Cont.fromDeferred(() => count(i + 1));
      }

      expect(outcomeOf(count(0)), equals('then $depth'));
    });

    test('left-nested local', () {
      Cont<int, int> cont = Cont.ask();
      for (var i = 0; i < depth; i++) {
        cont = cont.local((e) => e + 1);
      }

      int? result;
      cont.run(0, onThen: (v) => result = v);
      expect(result, equals(depth));
    });

    test(
      'local restores the environment after an async step',
      () async {
        final completer = Completer<List<int>>();
        final envs = <int>[];
        Cont.ask<int>()
            .thenDo((e) {
              envs.add(e);
              return Cont.fromRun<int, int>((runtime, o) {
                Timer(
                  Duration.zero,
                  () => o.onThen(runtime.env()),
                );
              });
            })
            .thenTap((e) {
              envs.add(e);
              return Cont.of<int, ()>(());
            })
            .local<int>((e) => e * 10)
            .thenDo((_) => Cont.ask<int>())
            .run(
              1,
              onThen: (e) {
                envs.add(e);
                completer.complete(envs);
              },
            );

        expect(await completer.future, equals([10, 10, 1]));
      },
    );

    test(
        'a throw from the thunk or from local\'s f stops it',
        () {
      expect(
        outcomeOf(
          Cont.fromDeferred<(), int>(() => throw 'thunk'),
        ),
        equals('else [thunk]'),
      );

      List<ContError>? errors;
      Cont.ask<int>()
          .local<int>((_) => throw 'local')
          .run(1, onElse: (e) => errors = e);
      expect(errors!.single.error, equals('local'));
    });
  });

  group('asynchronous steps', () {
    test(
      'a chain mixing synchronous and asynchronous steps',
      () async {
        Cont<(), int> later(int x) {
          return Cont.fromRun((runtime, observer) {
            Timer(Duration.zero,
                () => observer.onThen(x + 1));
          });
        }

        Cont<(), int> cont = Cont.of(0);
        for (var i = 0; i < 10000; i++) {
          cont = i % 1000 == 0
              ? cont.thenDo(later)
              : cont.thenMap((x) => x + 1);
        }

        final completer = Completer<int>();
        cont.run((), onThen: completer.complete);

        expect(await completer.future, equals(10000));
      },
    );
  });

  group('monad laws', () {
    Cont<(), int> f(int x) =>
        x.isEven ? Cont.of(x ~/ 2) : stopWith('odd $x');
    Cont<(), int> g(int x) =>
        x > 2 ? stopWith('big') : Cont.of(x * 10);

    for (final m in <String, Cont<(), int>>{
      'value': Cont.of(4),
      'errors': stopWith('e'),
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
          equals(
            outcomeOf(
                m.value.thenDo((x) => f(x).thenDo(g))),
          ),
        );
      });
    }

    for (final a in [3, 4, 8]) {
      test('left identity with $a', () {
        expect(
          outcomeOf(Cont.of<(), int>(a).thenDo(f)),
          equals(outcomeOf(f(a))),
        );
      });
    }
  });

  group('runs', () {
    test('runs of one Cont are independent', () {
      final observers = <ContObserver<int>>[];
      final leaf = Cont.fromRun<(), int>((runtime, o) {
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
      Cont.fromRun<(), int>((runtime, o) {
        o.onThen(1);
        log.add('leaf');
      }).thenDo((x) {
        log.add('next');
        return Cont.of<(), int>(x);
      }).run(());

      expect(log, equals(['leaf', 'next']));
    });

    test('a throw in a callback is a panic', () {
      ContError? panic;
      Cont.of<(), int>(1).thenMap((x) => x + 1).run(
        (),
        onThen: (_) => throw 'callback',
        onPanic: (p) => panic = p,
      );

      expect(panic!.error, equals('callback'));
    });

    test('a throw from f stops with that error', () {
      expect(
        outcomeOf(
          Cont.of<(), int>(1).thenDo<int>((_) => throw 'f'),
        ),
        equals('else [f]'),
      );
    });
  });

  group('cancel', () {
    test('a cancel mid-chain stops it without an outcome',
        () {
      final observers = <ContObserver<int>>[];
      final started = <int>[];
      Cont<(), int> leaf(int i) {
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
      );
      observers[0].onThen(0);
      token.cancel();
      observers[1].onThen(1);

      expect(started, equals([0, 1]));
      expect(outcomes, equals(0));
    });
  });
}
