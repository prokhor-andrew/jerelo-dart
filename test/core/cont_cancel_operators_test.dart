import 'dart:async';

import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

/// A leaf that waits until the test reports through [observer], and counts
/// how many times it was started and cancelled.
final class _Leaf<F, A> {
  SafeObserver<F, A>? observer;
  int starts = 0;
  int cancels = 0;

  /// Runs when the leaf is cancelled, after it was counted.
  final void Function(SafeObserver<F, A> observer)?
      onCancel;

  _Leaf({this.onCancel});

  late final Cont<(), F, A> cont =
      Cont.fromRun((_, observer) {
    starts += 1;
    this.observer = observer;
    return () {
      cancels += 1;
      onCancel?.call(observer);
    };
  });
}

/// Creates a leaf that reports `error` on the else channel when cancelled.
_Leaf<String, A> _reportingLeaf<A>(String error) {
  return _Leaf<String, A>(
    onCancel: (observer) => observer.onElse(error),
  );
}

final ContCrash _crash = (() {
  ContCrash? crash;
  Cont.fromRun<(), String, int>((_, o) {
    throw 'boom';
  }).run((), onCrash: (c) => crash = c);
  return crash!;
})();

void main() {
  group('runAll policies', () {
    test('either runAll forwards the cancel to both sides',
        () {
      final left = _Leaf<String, int>();
      final right = _Leaf<String, int>();
      Cont.either(
        left.cont,
        right.cont,
        (a, b) => '$a$b',
        policy: OkPolicy.runAll<int>(
          (a, b) => a + b,
          shouldFavorCrash: false,
        ),
      ).run(()).cancel();

      expect(left.cancels, equals(1));
      expect(right.cancels, equals(1));
    });

    test('either runAll does not cancel on its own', () {
      final left = _Leaf<String, int>();
      final right = _Leaf<String, int>();
      Cont.either(
        left.cont,
        right.cont,
        (a, b) => '$a$b',
        policy: OkPolicy.runAll<int>(
          (a, b) => a + b,
          shouldFavorCrash: false,
        ),
      ).run(());
      left.observer!.onThen(1);

      expect(right.cancels, equals(0));
    });

    test(
        'coalesce runAll forwards the cancel to both sides',
        () {
      final left = _Leaf<String, int>();
      final right = _Leaf<String, int>();
      Cont.coalesce(
        left.cont,
        right.cont,
        policy: CrashPolicy.runAll<String, int>(
          shouldFavorElse: false,
          combineElseVals: (a, b) => a + b,
          combineThenVals: (a, b) => a + b,
        ),
      ).run(()).cancel();

      expect(left.cancels, equals(1));
      expect(right.cancels, equals(1));
    });

    test('coalesce runAll does not cancel on its own', () {
      final left = _Leaf<String, int>();
      final right = _Leaf<String, int>();
      Cont.coalesce(
        left.cont,
        right.cont,
        policy: CrashPolicy.runAll<String, int>(
          shouldFavorElse: false,
          combineElseVals: (a, b) => a + b,
          combineThenVals: (a, b) => a + b,
        ),
      ).run(());
      left.observer!.onThen(1);

      expect(right.cancels, equals(0));
    });

    test(
        'converge runAll forwards the cancel to every item',
        () {
      final leaves =
          List.generate(3, (_) => _Leaf<String, int>());
      Cont.converge(
        leaves.map((l) => l.cont).toList(),
        policy: CrashPolicy.runAll<String, int>(
          shouldFavorElse: false,
          combineElseVals: (a, b) => a + b,
          combineThenVals: (a, b) => a + b,
        ),
      ).run(()).cancel();

      expect(leaves.map((l) => l.cancels), everyElement(1));
    });

    test('converge runAll does not cancel on its own', () {
      final leaves =
          List.generate(3, (_) => _Leaf<String, int>());
      Cont.converge(
        leaves.map((l) => l.cont).toList(),
        policy: CrashPolicy.runAll<String, int>(
          shouldFavorElse: false,
          combineElseVals: (a, b) => a + b,
          combineThenVals: (a, b) => a + b,
        ),
      ).run(());
      leaves[0].observer!.onThen(1);

      expect(leaves.map((l) => l.cancels), everyElement(0));
    });

    test('any runAll forwards the cancel to every item',
        () {
      final leaves =
          List.generate(3, (_) => _Leaf<String, int>());
      Cont.any(
        leaves.map((l) => l.cont).toList(),
        policy: OkPolicy.runAll<int>(
          (a, b) => a + b,
          shouldFavorCrash: false,
        ),
      ).run(()).cancel();

      expect(leaves.map((l) => l.cancels), everyElement(1));
    });

    test(
        'a runAll item cancelled after it finished is not cancelled again',
        () {
      final leaves =
          List.generate(2, (_) => _Leaf<String, int>());
      final token = Cont.all(
        leaves.map((l) => l.cont).toList(),
        policy: OkPolicy.runAll<String>(
          (a, b) => a + b,
          shouldFavorCrash: false,
        ),
      ).run(());
      leaves[0].observer!.onThen(1);
      token.cancel();

      expect(leaves[0].cancels, equals(0));
      expect(leaves[1].cancels, equals(1));
    });

    test(
        'runAll still delivers once every item reported a cancel',
        () {
      final leaves = List.generate(
        2,
        (i) => _reportingLeaf<int>('cancelled $i'),
      );
      String? error;
      Cont.all(
        leaves.map((l) => l.cont).toList(),
        policy: OkPolicy.runAll<String>(
          (a, b) => '$a+$b',
          shouldFavorCrash: false,
        ),
      ).run((), onElse: (e) => error = e).cancel();

      expect(error, equals('cancelled 0+cancelled 1'));
    });
  });

  group('sequence policies', () {
    test(
        'both sequence cancels the left side, then the right on start',
        () {
      final left = _Leaf<String, int>();
      final right = _Leaf<String, int>();
      final token = Cont.both(
        left.cont,
        right.cont,
        (a, b) => a + b,
        policy: OkPolicy.sequence(),
      ).run(());
      token.cancel();

      expect(left.cancels, equals(1));
      expect(right.starts, equals(0));

      left.observer!.onThen(1);

      expect(right.starts, equals(1));
      expect(right.cancels, equals(1));
    });

    test('either sequence cancels the running side', () {
      final left = _Leaf<String, int>();
      final right = _Leaf<String, int>();
      final token = Cont.either(
        left.cont,
        right.cont,
        (a, b) => '$a$b',
        policy: OkPolicy.sequence(),
      ).run(());
      left.observer!.onElse('left failed');
      token.cancel();

      expect(left.cancels, equals(0));
      expect(right.cancels, equals(1));
    });

    test('coalesce sequence cancels the running side', () {
      final left = _Leaf<String, int>();
      final right = _Leaf<String, int>();
      final token = Cont.coalesce(
        left.cont,
        right.cont,
        policy: CrashPolicy.sequence(),
      ).run(());
      left.observer!.onCrash(_crash);
      token.cancel();

      expect(left.cancels, equals(0));
      expect(right.cancels, equals(1));
    });

    test(
        'any sequence cancels the running item and later ones',
        () {
      final leaves =
          List.generate(3, (_) => _Leaf<String, int>());
      final token = Cont.any(
        leaves.map((l) => l.cont).toList(),
        policy: OkPolicy.sequence(),
      ).run(());
      leaves[0].observer!.onElse('first failed');
      token.cancel();

      expect(leaves[0].cancels, equals(0));
      expect(leaves[1].cancels, equals(1));
      expect(leaves[2].starts, equals(0));

      leaves[1].observer!.onElse('second failed');

      expect(leaves[2].starts, equals(1));
      expect(leaves[2].cancels, equals(1));
    });

    test(
        'converge sequence cancels the running item and later ones',
        () {
      final leaves =
          List.generate(3, (_) => _Leaf<String, int>());
      final token = Cont.converge(
        leaves.map((l) => l.cont).toList(),
        policy: CrashPolicy.sequence(),
      ).run(());
      leaves[0].observer!.onCrash(_crash);
      token.cancel();

      expect(leaves[0].cancels, equals(0));
      expect(leaves[1].cancels, equals(1));

      leaves[1].observer!.onCrash(_crash);

      expect(leaves[2].starts, equals(1));
      expect(leaves[2].cancels, equals(1));
    });

    test('a sequence of synchronous items stays stack safe',
        () {
      List<int>? result;
      Cont.all(
        List.generate(
          100000,
          (i) => Cont.of<(), String, int>(i),
        ),
        policy: OkPolicy.sequence(),
      ).run((), onThen: (v) => result = v);

      expect(result!.length, equals(100000));
    });
  });

  group('quitFast edge cases', () {
    test(
        'a side that decides synchronously cancels the other on start',
        () {
      final right = _Leaf<String, int>();
      String? error;
      Cont.both(
        Cont.error<(), String, int>('left failed'),
        right.cont,
        (a, b) => a + b,
        policy: OkPolicy.quitFast(),
      ).run((), onElse: (e) => error = e);

      expect(error, equals('left failed'));
      expect(right.starts, equals(1));
      expect(right.cancels, equals(1));
    });

    test('a loser reporting from its canceller is ignored',
        () {
      final left = _Leaf<String, int>();
      final right = _reportingLeaf<int>('right cancelled');
      final errors = <String>[];
      Cont.both(
        left.cont,
        right.cont,
        (a, b) => a + b,
        policy: OkPolicy.quitFast(),
      ).run((), onElse: errors.add);
      left.observer!.onElse('left failed');

      expect(errors, equals(['left failed']));
      expect(right.cancels, equals(1));
    });

    test(
        'a list loser reporting from its canceller is ignored',
        () {
      final leaves = List.generate(
        3,
        (i) => _reportingLeaf<int>('cancelled $i'),
      );
      final values = <int>[];
      Cont.any(
        leaves.map((l) => l.cont).toList(),
        policy: OkPolicy.quitFast(),
      ).run((), onThen: values.add);
      leaves[2].observer!.onThen(7);

      expect(values, equals([7]));
      expect(leaves[0].cancels, equals(1));
      expect(leaves[1].cancels, equals(1));
    });

    test('a crash decides and cancels the loser', () {
      final left = _Leaf<String, int>();
      final right = _Leaf<String, int>();
      ContCrash? crash;
      Cont.both(
        left.cont,
        right.cont,
        (a, b) => a + b,
        policy: OkPolicy.quitFast(),
      ).run((), onCrash: (c) => crash = c);
      left.observer!.onCrash(_crash);

      expect(crash, same(_crash));
      expect(right.cancels, equals(1));
    });

    test(
        'a cancel after the decision does not cancel again',
        () {
      final left = _Leaf<String, int>();
      final right = _Leaf<String, int>();
      final token = Cont.both(
        left.cont,
        right.cont,
        (a, b) => a + b,
        policy: OkPolicy.quitFast(),
      ).run(());
      left.observer!.onElse('left failed');
      token.cancel();

      expect(left.cancels, equals(0));
      expect(right.cancels, equals(1));
    });

    test('both quitFast with two successes cancels nobody',
        () {
      final left = _Leaf<String, int>();
      final right = _Leaf<String, int>();
      int? value;
      Cont.both(
        left.cont,
        right.cont,
        (a, b) => a + b,
        policy: OkPolicy.quitFast(),
      ).run((), onThen: (v) => value = v);
      left.observer!.onThen(1);
      right.observer!.onThen(2);

      expect(value, equals(3));
      expect(left.cancels, equals(0));
      expect(right.cancels, equals(0));
    });

    test(
        'coalesce quitFast waits for a second crash before deciding',
        () {
      final left = _Leaf<String, int>();
      final right = _Leaf<String, int>();
      ContCrash? crash;
      Cont.coalesce(
        left.cont,
        right.cont,
        policy: CrashPolicy.quitFast(),
      ).run((), onCrash: (c) => crash = c);
      left.observer!.onCrash(_crash);

      expect(right.cancels, equals(0));

      right.observer!.onCrash(_crash);

      expect(crash, isA<MergedCrash>());
    });

    test(
        'a cancel reaches the branches of a nested combinator',
        () {
      final first = _Leaf<String, int>();
      final left = _Leaf<String, int>();
      final right = _Leaf<String, int>();
      final token = first.cont.thenDo((_) {
        return Cont.both(
          left.cont,
          right.cont,
          (a, b) => a + b,
          policy: OkPolicy.quitFast(),
        );
      }).run(());
      first.observer!.onThen(1);
      token.cancel();

      expect(left.cancels, equals(1));
      expect(right.cancels, equals(1));
    });

    test('the instance forms forward the cancel', () {
      final leaves =
          List.generate(6, (_) => _Leaf<String, int>());
      leaves[0]
          .cont
          .and(
            leaves[1].cont,
            (a, b) => a + b,
            policy: OkPolicy.quitFast(),
          )
          .run(()).cancel();
      leaves[2]
          .cont
          .or(
            leaves[3].cont,
            (a, b) => '$a$b',
            policy: OkPolicy.quitFast(),
          )
          .run(()).cancel();
      leaves[4]
          .cont
          .coalesceWith(
            leaves[5].cont,
            policy: CrashPolicy.quitFast(),
          )
          .run(()).cancel();

      expect(leaves.map((l) => l.cancels), everyElement(1));
    });
  });

  group('derived operators', () {
    test(
        'thenTap forwards to the main computation, then to the tap',
        () {
      final main = _Leaf<String, int>();
      final tap = _Leaf<String, int>();
      final token =
          main.cont.thenTap((_) => tap.cont).run(());
      main.observer!.onThen(1);
      token.cancel();

      expect(main.cancels, equals(0));
      expect(tap.cancels, equals(1));
    });

    test('elseTap and crashTap forward to the running tap',
        () {
      final elseTap = _Leaf<String, int>();
      final crashTap = _Leaf<String, int>();
      Cont.error<(), String, int>('e')
          .elseTap((_) => elseTap.cont)
          .run(()).cancel();
      Cont.crash<(), String, int>(_crash)
          .crashTap((_) => crashTap.cont)
          .run(()).cancel();

      expect(elseTap.cancels, equals(1));
      expect(crashTap.cancels, equals(1));
    });

    test('zips forward to the running second computation',
        () {
      final thenZip = _Leaf<String, int>();
      final elseZip = _Leaf<String, int>();
      final crashZip = _Leaf<String, int>();
      Cont.of<(), String, int>(1)
          .thenZip((_) => thenZip.cont, (a, b) => a + b)
          .run(()).cancel();
      Cont.error<(), String, int>('e')
          .elseZip((_) => elseZip.cont, (a, b) => '$a$b')
          .run(()).cancel();
      Cont.crash<(), String, int>(_crash)
          .crashZip((_) => crashZip.cont)
          .run(()).cancel();

      expect(thenZip.cancels, equals(1));
      expect(elseZip.cancels, equals(1));
      expect(crashZip.cancels, equals(1));
    });

    test('the 0 and WithEnv variants forward the cancel',
        () {
      final leaves =
          List.generate(4, (_) => _Leaf<String, int>());
      Cont.of<(), String, int>(1)
          .thenDo0(() => leaves[0].cont)
          .run(()).cancel();
      Cont.of<(), String, int>(1)
          .thenDoWithEnv((_, __) => leaves[1].cont)
          .run(()).cancel();
      Cont.error<(), String, int>('e')
          .elseDoWithEnv0((_) => leaves[2].cont)
          .run(()).cancel();
      Cont.of<(), String, int>(1)
          .thenTapWithEnv0((_) => leaves[3].cont)
          .run(()).cancel();

      expect(leaves.map((l) => l.cancels), everyElement(1));
    });

    test(
        'channel switches and conditions forward the cancel',
        () {
      final leaves =
          List.generate(6, (_) => _Leaf<String, int>());
      leaves[0].cont.demote((v) => '$v').run(()).cancel();
      leaves[1]
          .cont
          .promote((e) => e.length)
          .run(()).cancel();
      leaves[2]
          .cont
          .thenIf((v) => v > 0, fallback: 'negative')
          .run(()).cancel();
      leaves[3]
          .cont
          .elseUnless((e) => e.isEmpty, fallback: 0)
          .run(()).cancel();
      leaves[4]
          .cont
          .crashUnlessThen((_) => false, fallback: 0)
          .run(()).cancel();
      leaves[5]
          .cont
          .crashRecoverThen((_) => 0)
          .run(()).cancel();

      expect(leaves.map((l) => l.cancels), everyElement(1));
    });

    test('environment operators forward the cancel', () {
      final leaves =
          List.generate(4, (_) => _Leaf<String, int>());
      leaves[0].cont.withEnv(()).run(()).cancel();
      leaves[1].cont.local0<int>(() => ()).run(0).cancel();
      Cont.of<(), String, ()>(())
          .thenInject(leaves[2].cont)
          .run(()).cancel();
      leaves[3]
          .cont
          .injectedByThen(Cont.of<int, String, ()>(()))
          .run(0)
          .cancel();

      expect(leaves.map((l) => l.cancels), everyElement(1));
    });

    test(
        'elseFork and crashFork keep the side effect detached',
        () {
      final elseSide = _Leaf<String, int>();
      final crashSide = _Leaf<String, int>();
      Cont.error<(), String, int>('e')
          .elseFork((_) => elseSide.cont)
          .run(()).cancel();
      Cont.crash<(), String, int>(_crash)
          .crashFork((_) => crashSide.cont)
          .run(()).cancel();

      expect(elseSide.starts, equals(1));
      expect(elseSide.cancels, equals(0));
      expect(crashSide.starts, equals(1));
      expect(crashSide.cancels, equals(0));
    });

    test(
        'a fork builder that throws still crashes after a cancel',
        () {
      final main = _Leaf<String, int>();
      ContCrash? crash;
      final token = main.cont
          .thenFork<String, int>((_) => throw 'builder')
          .run((), onCrash: (c) => crash = c);
      token.cancel();
      main.observer!.onThen(1);

      expect(main.cancels, equals(1));
      expect(
          (crash as NormalCrash).error, equals('builder'));
    });
  });

  group('loops', () {
    test(
        'elseWhile ends with the error its attempt reports on cancel',
        () {
      final attempts = <_Leaf<String, int>>[];
      String? error;
      var predicateCalls = 0;
      final token = Cont.fromDeferred(() {
        final leaf = _reportingLeaf<int>('cancelled');
        attempts.add(leaf);
        return leaf.cont;
      }).elseWhile((_) {
        predicateCalls++;
        return true;
      }).run((), onElse: (e) => error = e);
      token.cancel();

      expect(attempts.length, equals(1));
      expect(predicateCalls, equals(0));
      expect(error, equals('cancelled'));
    });

    test(
        'a bounded elseWhile starts no attempt after a cancel',
        () {
      var started = 0;
      String? error;
      final token = Cont.fromDeferred(() {
        started++;
        return _reportingLeaf<int>('cancelled').cont;
      })
          .elseWhile((_) => started < 6)
          .run((), onElse: (e) => error = e);
      token.cancel();

      expect(started, equals(1));
      expect(error, equals('cancelled'));
    });

    test(
        'crashWhile ends with the crash its attempt reports on cancel',
        () {
      var started = 0;
      ContCrash? crash;
      final token = Cont.fromDeferred(() {
        started++;
        return _Leaf<String, int>(
          onCancel: (observer) => observer.onCrash(_crash),
        ).cont;
      })
          .crashWhile((_) => true)
          .run((), onCrash: (c) => crash = c);
      token.cancel();

      expect(started, equals(1));
      expect(crash, same(_crash));
    });

    test(
        'thenUntil ends with the value its iteration reports on cancel',
        () {
      var started = 0;
      int? result;
      final token = Cont.fromDeferred(() {
        started++;
        return _Leaf<String, int>(
          onCancel: (observer) => observer.onThen(7),
        ).cont;
      })
          .thenUntil((_) => false)
          .run((), onThen: (v) => result = v);
      token.cancel();

      expect(started, equals(1));
      expect(result, equals(7));
    });

    test(
        'an endless thenWhile forwards to the running iteration',
        () {
      final leaves = <_Leaf<String, int>>[];
      final token = Cont.fromDeferred(() {
        final leaf = _Leaf<String, int>();
        leaves.add(leaf);
        return leaf.cont;
      }).thenWhile((_) => true).run(());
      leaves.last.observer!.onThen(1);
      leaves.last.observer!.onThen(2);
      token.cancel();

      expect(leaves.length, equals(3));
      expect(leaves[0].cancels, equals(0));
      expect(leaves[1].cancels, equals(0));
      expect(leaves[2].cancels, equals(1));
    });

    test(
        'an endless thenWhile ends when its step reports the cancel',
        () {
      String? error;
      final token = Cont.fromDeferred(
        () => _reportingLeaf<int>('stopped').cont,
      )
          .thenWhile((_) => true)
          .run((), onElse: (e) => error = e);
      token.cancel();

      expect(error, equals('stopped'));
    });

    test(
        'elseWhile, crashWhile and thenUntil forward the cancel',
        () {
      final leaves =
          List.generate(3, (_) => _Leaf<String, int>());
      leaves[0]
          .cont
          .elseWhile((_) => true)
          .run(()).cancel();
      leaves[1]
          .cont
          .crashWhile((_) => true)
          .run(()).cancel();
      leaves[2]
          .cont
          .thenUntil((_) => false)
          .run(()).cancel();

      expect(leaves.map((l) => l.cancels), everyElement(1));
    });

    test(
        'a retry loop stops once a retry reports the cancel',
        () {
      final attempts = <_Leaf<String, int>>[];
      String? error;
      final token = Cont.fromDeferred(() {
        final leaf = _reportingLeaf<int>('cancelled');
        attempts.add(leaf);
        return leaf.cont;
      }).crashWhile((_) => true).run(
        (),
        onElse: (e) => error = e,
      );
      attempts.last.observer!.onCrash(_crash);
      attempts.last.observer!.onCrash(_crash);
      token.cancel();

      expect(attempts.length, equals(3));
      expect(attempts[2].cancels, equals(1));
      expect(error, equals('cancelled'));
    });
  });

  group('leaves and the token', () {
    test(
        'a leaf that throws synchronously has a no-op canceller',
        () {
      final crashes = <ContCrash>[];
      Cont.fromRun<(), String, int>((_, o) {
        throw 'boom';
      }).run((), onCrash: crashes.add).cancel();

      expect(crashes.length, equals(1));
    });

    test(
        'a throwing canceller crashes once, later reports are ignored',
        () {
      SafeObserver<String, int>? observer;
      final crashes = <ContCrash>[];
      final values = <int>[];
      final token = Cont.fromRun<(), String, int>((_, o) {
        observer = o;
        return () => throw 'cancel failed';
      }).run((), onCrash: crashes.add, onThen: values.add);
      token.cancel();
      observer!.onThen(1);

      expect(crashes.length, equals(1));
      expect(values, isEmpty);
    });

    test(
        'cancelling from inside the result callback does nothing',
        () {
      final leaf = _Leaf<String, int>();
      late final ContCancelToken token;
      token =
          leaf.cont.run((), onThen: (_) => token.cancel());
      leaf.observer!.onThen(1);

      expect(token.isCancelled(), isTrue);
      expect(leaf.cancels, equals(0));
    });

    test(
        'decorate that drops the canceller stops propagation',
        () {
      final leaf = _Leaf<String, int>();
      leaf.cont.decorate((run, env, observer) {
        run(env, observer);
        return () {};
      }).run(()).cancel();

      expect(leaf.cancels, equals(0));
    });

    test('Cont.fromDeferred with a throwing thunk crashes',
        () {
      ContCrash? crash;
      Cont.fromDeferred<(), String, int>(
              () => throw 'thunk')
          .run((), onCrash: (c) => crash = c).cancel();

      expect((crash as NormalCrash).error, equals('thunk'));
    });

    test(
        'a timer leaf cancelled while waiting reports at once',
        () async {
      final completer = Completer<String>();
      final token =
          Cont.fromRun<(), String, int>((_, observer) {
        final timer = Timer(const Duration(seconds: 5), () {
          observer.onThen(1);
        });
        return () {
          timer.cancel();
          observer.onElse('cancelled');
        };
      }).thenWhile((_) => true).run(
        (),
        onElse: completer.complete,
        onThen: (_) => completer.complete('finished'),
      );
      Timer(const Duration(milliseconds: 10), token.cancel);

      expect(
        await completer.future
            .timeout(const Duration(seconds: 1)),
        equals('cancelled'),
      );
    });
  });

  group('Cont.bracket', () {
    test('use throwing synchronously still releases', () {
      var releases = 0;
      ContCrash? crash;
      Cont.bracket<int, (), String, int>(
        acquire: Cont.of(1),
        release: (_) => Cont.fromRun((_, o) {
          releases += 1;
          o.onThen(());
          return () {};
        }),
        use: (_) => throw 'use',
      ).run((), onCrash: (c) => crash = c).cancel();

      expect(releases, equals(1));
      expect((crash as NormalCrash).error, equals('use'));
    });

    test('a cancel after use finished does nothing', () {
      final use = _Leaf<String, int>();
      var releases = 0;
      final token = Cont.bracket<int, (), String, int>(
        acquire: Cont.of(1),
        release: (_) => Cont.fromRun((_, o) {
          releases += 1;
          o.onThen(());
          return () {};
        }),
        use: (_) => use.cont,
      ).run(());
      use.observer!.onThen(2);
      token.cancel();

      expect(use.cancels, equals(0));
      expect(releases, equals(1));
    });

    test(
        'a timer download cancelled mid-way releases at once',
        () async {
      final events = <String>[];
      final done = Completer<void>();
      final token =
          Cont.bracket<String, (), String, String>(
        acquire: Cont.fromRun((_, o) {
          events.add('open');
          o.onThen('conn');
          return () {};
        }),
        release: (conn) => Cont.fromRun((_, o) {
          events.add('close $conn');
          o.onThen(());
          done.complete();
          return () {};
        }),
        use: (conn) => Cont.fromRun((_, o) {
          final timer =
              Timer(const Duration(seconds: 5), () {
            o.onThen('data');
          });
          return () {
            timer.cancel();
            o.onElse('cancelled');
          };
        }),
      ).run((), onElse: events.add);
      Timer(const Duration(milliseconds: 10), token.cancel);
      await done.future.timeout(const Duration(seconds: 1));

      expect(events,
          equals(['open', 'cancelled', 'close conn']));
    });
  });
}
