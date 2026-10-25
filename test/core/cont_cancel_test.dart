import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

/// A leaf that waits until the test reports through [observer], and counts
/// how many times it was cancelled.
final class _Leaf<F, A> {
  SafeObserver<F, A>? observer;
  int starts = 0;
  int cancels = 0;

  late final Cont<(), F, A> cont =
      Cont.fromRun((_, observer) {
    starts += 1;
    this.observer = observer;
    return () {
      cancels += 1;
    };
  });
}

void main() {
  group('ContCancelToken', () {
    test('cancel reaches the running leaf once', () {
      final leaf = _Leaf<String, int>();
      final token = leaf.cont.run(());

      expect(token.isCancelled(), isFalse);
      token.cancel();
      token.cancel();

      expect(token.isCancelled(), isTrue);
      expect(leaf.cancels, equals(1));
    });

    test('cancel after completion does not reach the leaf',
        () {
      final leaf = _Leaf<String, int>();
      int? value;
      final token = leaf.cont.run(
        (),
        onThen: (v) => value = v,
      );
      leaf.observer!.onThen(1);
      token.cancel();

      expect(value, equals(1));
      expect(leaf.cancels, equals(0));
    });

    test('the leaf decides how cancellation is reported',
        () {
      final leaf = _Leaf<String, int>();
      String? error;
      final token = leaf.cont.run(
        (),
        onElse: (e) => error = e,
      );
      token.cancel();
      leaf.observer!.onElse('cancelled');

      expect(error, equals('cancelled'));
    });

    test('a leaf returning a no-op just finishes', () {
      SafeObserver<String, int>? observer;
      int? value;
      final token = Cont.fromRun<(), String, int>((_, o) {
        observer = o;
        return () {};
      }).run((), onThen: (v) => value = v);
      token.cancel();
      observer!.onThen(7);

      expect(value, equals(7));
    });

    test('a throwing canceller crashes the computation',
        () {
      ContCrash? crash;
      final token = Cont.fromRun<(), String, int>((_, o) {
        return () => throw 'boom';
      }).run((), onCrash: (c) => crash = c);
      token.cancel();

      expect(crash, isA<NormalCrash>());
      expect((crash as NormalCrash).error, equals('boom'));
    });
  });

  group('sequential operators', () {
    test('thenDo cancels the running stage', () {
      final first = _Leaf<String, int>();
      final second = _Leaf<String, int>();
      final token =
          first.cont.thenDo((_) => second.cont).run(());
      token.cancel();

      expect(first.cancels, equals(1));
      expect(second.starts, equals(0));
    });

    test(
        'thenDo cancels a stage that starts after the cancel',
        () {
      final first = _Leaf<String, int>();
      final second = _Leaf<String, int>();
      final token =
          first.cont.thenDo((_) => second.cont).run(());
      token.cancel();
      first.observer!.onThen(1);

      expect(second.starts, equals(1));
      expect(second.cancels, equals(1));
    });

    test('thenDo cancels the second stage once it runs',
        () {
      final first = _Leaf<String, int>();
      final second = _Leaf<String, int>();
      final token =
          first.cont.thenDo((_) => second.cont).run(());
      first.observer!.onThen(1);
      token.cancel();

      expect(first.cancels, equals(0));
      expect(second.cancels, equals(1));
    });

    test('elseDo and crashDo forward the cancel', () {
      final elseLeaf = _Leaf<String, int>();
      final crashLeaf = _Leaf<String, int>();
      final elseToken = Cont.error<(), String, int>('e')
          .elseDo((_) => elseLeaf.cont)
          .run(());
      final crashToken =
          Cont.fromRun<(), String, int>((_, o) {
        throw 'x';
      }).crashDo((_) => crashLeaf.cont).run(());
      elseToken.cancel();
      crashToken.cancel();

      expect(elseLeaf.cancels, equals(1));
      expect(crashLeaf.cancels, equals(1));
    });

    test(
        'local, fromDeferred and decorate forward the cancel',
        () {
      final a = _Leaf<String, int>();
      final b = _Leaf<String, int>();
      final c = _Leaf<String, int>();
      a.cont.local<int>((_) => ()).run(0).cancel();
      Cont.fromDeferred(() => b.cont).run(()).cancel();
      c.cont
          .decorate(
              (run, env, observer) => run(env, observer))
          .run(()).cancel();

      expect(a.cancels, equals(1));
      expect(b.cancels, equals(1));
      expect(c.cancels, equals(1));
    });
  });

  group('combinators', () {
    test('both quitFast cancels the loser once decided',
        () {
      final left = _Leaf<String, int>();
      final right = _Leaf<String, int>();
      String? error;
      Cont.both(
        left.cont,
        right.cont,
        (a, b) => a + b,
        policy: OkPolicy.quitFast(),
      ).run((), onElse: (e) => error = e);
      left.observer!.onElse('left failed');

      expect(error, equals('left failed'));
      expect(right.cancels, equals(1));
    });

    test('either quitFast cancels the loser once decided',
        () {
      final left = _Leaf<String, int>();
      final right = _Leaf<String, int>();
      int? value;
      Cont.either(
        left.cont,
        right.cont,
        (a, b) => '$a$b',
        policy: OkPolicy.quitFast(),
      ).run((), onThen: (v) => value = v);
      right.observer!.onThen(2);

      expect(value, equals(2));
      expect(left.cancels, equals(1));
    });

    test('coalesce quitFast cancels the loser once decided',
        () {
      final left = _Leaf<String, int>();
      final right = _Leaf<String, int>();
      Cont.coalesce(
        left.cont,
        right.cont,
        policy: CrashPolicy.quitFast(),
      ).run(());
      left.observer!.onThen(1);

      expect(right.cancels, equals(1));
    });

    test(
        'runAll forwards the cancel and does not cancel on its own',
        () {
      final left = _Leaf<String, int>();
      final right = _Leaf<String, int>();
      final token = Cont.both(
        left.cont,
        right.cont,
        (a, b) => a + b,
        policy: OkPolicy.runAll<String>(
          (a, b) => a + b,
          shouldFavorCrash: false,
        ),
      ).run(());
      left.observer!.onElse('left failed');

      expect(right.cancels, equals(0));

      token.cancel();

      expect(left.cancels, equals(0)); // already finished
      expect(right.cancels, equals(1));
    });

    test('all quitFast cancels the rest once decided', () {
      final leaves =
          List.generate(3, (_) => _Leaf<String, int>());
      Cont.all(
        leaves.map((l) => l.cont).toList(),
        policy: OkPolicy.quitFast(),
      ).run(());
      leaves[1].observer!.onElse('failed');

      expect(leaves[0].cancels, equals(1));
      expect(leaves[1].cancels, equals(0));
      expect(leaves[2].cancels, equals(1));
    });

    test('any quitFast cancels the rest once decided', () {
      final leaves =
          List.generate(3, (_) => _Leaf<String, int>());
      Cont.any(
        leaves.map((l) => l.cont).toList(),
        policy: OkPolicy.quitFast(),
      ).run(());
      leaves[0].observer!.onThen(1);

      expect(leaves[1].cancels, equals(1));
      expect(leaves[2].cancels, equals(1));
    });

    test('converge quitFast cancels the rest once decided',
        () {
      final leaves =
          List.generate(2, (_) => _Leaf<String, int>());
      Cont.converge(
        leaves.map((l) => l.cont).toList(),
        policy: CrashPolicy.quitFast(),
      ).run(());
      leaves[0].observer!.onThen(1);

      expect(leaves[1].cancels, equals(1));
    });

    test(
        'all sequence cancels the running item and later ones',
        () {
      final leaves =
          List.generate(2, (_) => _Leaf<String, int>());
      final token = Cont.all(
        leaves.map((l) => l.cont).toList(),
        policy: OkPolicy.sequence(),
      ).run(());
      token.cancel();

      expect(leaves[0].cancels, equals(1));
      expect(leaves[1].starts, equals(0));

      leaves[0].observer!.onThen(1);

      expect(leaves[1].starts, equals(1));
      expect(leaves[1].cancels, equals(1));
    });

    test('runAll list forwards the cancel to every item',
        () {
      final leaves =
          List.generate(3, (_) => _Leaf<String, int>());
      Cont.all(
        leaves.map((l) => l.cont).toList(),
        policy: OkPolicy.runAll<String>(
          (a, b) => a + b,
          shouldFavorCrash: false,
        ),
      ).run(()).cancel();

      expect(leaves.map((l) => l.cancels), everyElement(1));
    });
  });

  group('loops', () {
    test(
        'after a cancel, a loop ends with the running iteration',
        () {
      final leaves = <_Leaf<String, int>>[];
      int? result;
      final token = Cont.fromDeferred<(), String, int>(() {
        final leaf = _Leaf<String, int>();
        leaves.add(leaf);
        return leaf.cont;
      }).thenWhile((_) => true).run(
        (),
        onThen: (v) => result = v,
      );
      token.cancel();

      expect(leaves.single.cancels, equals(1));

      // the iteration ignores the cancel and finishes later
      leaves.single.observer!.onThen(1);

      expect(leaves.length, equals(1));
      expect(result, equals(1));
    });

    test(
        'a loop forwards the cancel to its running iteration',
        () {
      final leaf = _Leaf<String, int>();
      leaf.cont.thenWhile((v) => v < 10).run(()).cancel();

      expect(leaf.cancels, equals(1));
    });
  });

  group('Cont.bracket', () {
    test(
        'a cancel reaches use; use is released once it reports',
        () {
      final use = _Leaf<String, int>();
      var releases = 0;
      String? error;
      final token = Cont.bracket<int, (), String, int>(
        acquire: Cont.of(1),
        release: (_, __) => Cont.fromRun((_, o) {
          releases += 1;
          o.onThen(());
          return () {};
        }),
        use: (_) => use.cont,
      ).run((), onElse: (e) => error = e);
      token.cancel();

      expect(use.cancels, equals(1));
      expect(releases, equals(0));

      use.observer!.onElse('cancelled');

      expect(releases, equals(1));
      expect(error, equals('cancelled'));
    });

    test(
        'a cancel reaches acquire; use is cancelled once it starts',
        () {
      final acquire = _Leaf<Never, int>();
      final use = _Leaf<String, int>();
      var releases = 0;
      final token = Cont.bracket<int, (), String, int>(
        acquire: acquire.cont,
        release: (_, __) => Cont.fromRun((_, o) {
          releases += 1;
          o.onThen(());
          return () {};
        }),
        use: (_) => use.cont,
      ).run(());
      token.cancel();

      expect(acquire.cancels, equals(1));

      acquire.observer!.onThen(1);

      expect(use.cancels, equals(1));

      use.observer!.onThen(2);

      expect(releases, equals(1));
    });

    test('a cancel reaches release: its leaf decides', () {
      final release = _Leaf<Never, ()>();
      final token = Cont.bracket<int, (), String, int>(
        acquire: Cont.of(1),
        release: (_, __) => release.cont,
        use: (_) => Cont.of(2),
      ).run(());
      token.cancel();

      expect(release.starts, equals(1));
      expect(release.cancels, equals(1));
    });
  });

  group('forks', () {
    test('the side effect is not cancelled with the parent',
        () {
      final side = _Leaf<String, int>();
      final main = _Leaf<String, int>();
      final token =
          main.cont.thenFork((_) => side.cont).run(());
      main.observer!.onThen(1);
      token.cancel();

      expect(side.starts, equals(1));
      expect(side.cancels, equals(0));
    });

    test('the main computation is cancelled', () {
      final side = _Leaf<String, int>();
      final main = _Leaf<String, int>();
      main.cont.thenFork((_) => side.cont).run(()).cancel();

      expect(main.cancels, equals(1));
    });
  });
}
