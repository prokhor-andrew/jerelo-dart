import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

Cont<(), Never, ()> _release(List<String> log,
    [String name = 'release']) {
  return Cont.fromRun((env, observer) {
    log.add(name);
    observer.onThen(());
    return () {};
  });
}

Cont<(), Never, ()> _crashingRelease(List<String> log) {
  return Cont.fromRun((env, observer) {
    log.add('release');
    observer.onCrash(_crash('release'));
    return () {};
  });
}

extension on CrashOr<Object?> {
  NormalCrash get crashOrThrow => switch (this) {
        CrashCrashOr(:final crash) => crash,
        ValueCrashOr() => throw StateError('not a crash'),
      };
}

NormalCrash _crash(Object error) =>
    ContCrash.tryCatch<void>(() => throw error)
        .crashOrThrow;

/// A leaf that reports when told to, and counts the cancels it got.
final class _Leaf<F, A> {
  ContObserver<F, A>? observer;
  var starts = 0;
  var cancels = 0;
  bool reportsCancel = false;

  late final Cont<(), F, A> cont = Cont.fromRun((env, o) {
    starts++;
    observer = o;
    return () {
      cancels++;
      if (reportsCancel) {
        o.onElse('cancelled' as F);
      }
    };
  });
}

void main() {
  group('Cont.bracket', () {
    test('acquires, uses, releases, then reports', () {
      final log = <String>[];
      int? result;
      Cont.bracket<String, (), String, int>(
        acquire: Cont.fromRun((env, observer) {
          log.add('acquire');
          observer.onThen('resource');
          return () {};
        }),
        release: (r, _) {
          log.add('release:$r');
          return Cont.of(());
        },
        use: (r) => Cont.fromRun((env, observer) {
          log.add('use:$r');
          observer.onThen(42);
          return () {};
        }),
      ).run((), onThen: (v) {
        log.add('result');
        result = v;
      });

      expect(
          log,
          equals([
            'acquire',
            'use:resource',
            'release:resource',
            'result'
          ]));
      expect(result, equals(42));
    });

    test('the outcome waits for a release that takes time',
        () {
      final release = _Leaf<Never, ()>();
      int? result;
      Cont.bracket<int, (), String, int>(
        acquire: Cont.of(1),
        release: (_, __) => release.cont,
        use: (_) => Cont.of(2),
      ).run((), onThen: (v) => result = v);

      expect(release.starts, equals(1));
      expect(result, isNull);

      release.observer!.onThen(());

      expect(result, equals(2));
    });

    test(
        'releases on use failure and reports the failure after',
        () {
      final log = <String>[];
      String? error;
      Cont.bracket<String, (), String, int>(
        acquire: Cont.of('resource'),
        release: (_, __) => _release(log),
        use: (r) => Cont.error('error'),
      ).run((), onElse: (e) {
        log.add('error');
        error = e;
      });

      expect(log, equals(['release', 'error']));
      expect(error, equals('error'));
    });

    test('supports multiple runs', () {
      var releases = 0;
      final cont = Cont.bracket<String, (), String, int>(
        acquire: Cont.of('resource'),
        release: (_, __) {
          releases++;
          return Cont.of(());
        },
        use: (r) => Cont.of(42),
      );

      int? first;
      int? second;
      cont.run((), onThen: (v) => first = v);
      cont.run((), onThen: (v) => second = v);

      expect(first, equals(42));
      expect(second, equals(42));
      expect(releases, equals(2));
    });

    test(
        'release gets the resource, and a use that gets it too',
        () {
      String? inUse;
      String? inRelease;
      Cont.bracket<String, (), String, int>(
        acquire: Cont.of('my-resource'),
        release: (r, _) {
          inRelease = r;
          return Cont.of(());
        },
        use: (r) {
          inUse = r;
          return Cont.of(1);
        },
      ).run(());

      expect(inUse, equals('my-resource'));
      expect(inRelease, equals('my-resource'));
    });
  });

  group('Cont.bracket crashes', () {
    ContCrash? run({
      required Cont<(), Never, String> acquire,
      required Cont<(), Never, ()> Function(
              String, BracketOutcome<String, int>)
          release,
      required Cont<(), String, int> Function(String) use,
    }) {
      ContCrash? crash;
      Cont.bracket<String, (), String, int>(
        acquire: acquire,
        release: release,
        use: use,
      ).run((), onCrash: (c) => crash = c);
      return crash;
    }

    final acquireCrash = Cont.fromRun<(), Never, String>(
      (env, observer) => throw 'acquire',
    );

    test('acquire crash: release does not run', () {
      final log = <String>[];
      final crash = run(
        acquire: acquireCrash,
        release: (_, __) => _release(log),
        use: (_) => Cont.of(1),
      );

      expect(log, isEmpty);
      expect(crash, equals(_crash('acquire')));
    });

    test('use crash', () {
      final log = <String>[];
      final crash = run(
        acquire: Cont.of('r'),
        release: (_, __) => _release(log),
        use: (_) =>
            Cont.fromRun((env, observer) => throw 'use'),
      );

      expect(log, equals(['release']));
      expect(crash, equals(_crash('use')));
    });

    test('use throwing while being built is a use crash',
        () {
      final log = <String>[];
      final crash = run(
        acquire: Cont.of('r'),
        release: (_, __) => _release(log),
        use: (_) => throw 'build',
      );

      expect(log, equals(['release']));
      expect(crash, equals(_crash('build')));
    });

    test('use crash and release crash', () {
      final crash = run(
        acquire: Cont.of('r'),
        release: (_, __) => _crashingRelease([]),
        use: (_) =>
            Cont.fromRun((env, observer) => throw 'use'),
      );

      expect(
        crash,
        equals(ContCrash.merge(
            _crash('use'), _crash('release'))),
      );
    });

    test('release crash alone replaces a success', () {
      int? value;
      ContCrash? crash;
      Cont.bracket<String, (), String, int>(
        acquire: Cont.of('r'),
        release: (_, __) => _crashingRelease([]),
        use: (_) => Cont.of(1),
      ).run((),
          onThen: (v) => value = v,
          onCrash: (c) => crash = c);

      expect(value, isNull);
      expect(crash, equals(_crash('release')));
    });

    test('release crash alone replaces a failure', () {
      String? error;
      ContCrash? crash;
      Cont.bracket<String, (), String, int>(
        acquire: Cont.of('r'),
        release: (_, __) => _crashingRelease([]),
        use: (_) => Cont.error('e'),
      ).run((),
          onElse: (e) => error = e,
          onCrash: (c) => crash = c);

      expect(error, isNull);
      expect(crash, equals(_crash('release')));
    });

    test(
        'a release that throws while being built is a release crash',
        () {
      final crash = run(
        acquire: Cont.of('r'),
        release: (_, __) => throw 'release',
        use: (_) => Cont.of(1),
      );

      expect(crash, equals(_crash('release')));
    });
  });

  group('Cont.bracket release outcome', () {
    BracketOutcome<String, int>? seenBy(
      Cont<(), String, int> Function(String) use,
    ) {
      BracketOutcome<String, int>? seen;
      Cont.bracket<String, (), String, int>(
        acquire: Cont.of('r'),
        release: (_, outcome) {
          seen = outcome;
          return Cont.of(());
        },
        use: use,
      ).run(());
      return seen;
    }

    test('release gets the value use succeeded with', () {
      final seen = seenBy((_) => Cont.of(7));

      expect(seen, isA<ThenBracketOutcome<String, int>>());
      expect(
        (seen as ThenBracketOutcome<String, int>).value,
        equals(7),
      );
    });

    test('release gets the error use failed with', () {
      final seen = seenBy((_) => Cont.error('bad'));

      expect(seen, isA<ElseBracketOutcome<String, int>>());
      expect(
        (seen as ElseBracketOutcome<String, int>).error,
        equals('bad'),
      );
    });

    test('release gets the crash use ended with', () {
      final seen = seenBy(
        (_) => Cont.fromRun((env, observer) => throw 'use'),
      );

      expect(seen, isA<CrashBracketOutcome<String, int>>());
      expect(
        (seen as CrashBracketOutcome<String, int>).crash,
        equals(_crash('use')),
      );
    });

    test('release gets a crash when use throws while built',
        () {
      final seen = seenBy((_) => throw 'build');

      expect(seen, isA<CrashBracketOutcome<String, int>>());
      expect(
        (seen as CrashBracketOutcome<String, int>).crash,
        equals(_crash('build')),
      );
    });

    test('a use outcome is reported again after release',
        () {
      final log = <String>[];
      Cont.bracket<String, (), String, int>(
        acquire: Cont.of('r'),
        release: (_, __) => _release(log),
        use: (_) => Cont.error('bad'),
      ).run((), onElse: (e) => log.add('else $e'));

      expect(log, equals(['release', 'else bad']));
    });
  });

  group('Cont.bracket cancellation', () {
    test(
        'a use that stops silently is never released, '
        'nothing is reported', () {
      final use = _Leaf<String, int>();
      final log = <String>[];
      var reports = 0;
      Cont.bracket<int, (), String, int>(
        acquire: Cont.of(1),
        release: (_, __) => _release(log),
        use: (_) => use.cont,
      ).run(
        (),
        onThen: (_) => reports++,
        onElse: (_) => reports++,
        onCrash: (_) => reports++,
      ).cancel();

      expect(use.cancels, equals(1));
      expect(log, isEmpty);
      expect(reports, equals(0));
    });

    test(
        'a use that reports its cancel is released before it is reported',
        () {
      final use = _Leaf<String, int>()
        ..reportsCancel = true;
      final log = <String>[];
      Cont.bracket<int, (), String, int>(
        acquire: Cont.of(1),
        release: (_, __) => _release(log),
        use: (_) => use.cont,
      ).run((), onElse: (e) => log.add(e)).cancel();

      expect(log, equals(['release', 'cancelled']));
    });

    test('release sees the cancel that use reported', () {
      final use = _Leaf<String, int>()
        ..reportsCancel = true;
      BracketOutcome<String, int>? seen;
      Cont.bracket<int, (), String, int>(
        acquire: Cont.of(1),
        release: (_, outcome) {
          seen = outcome;
          return Cont.of(());
        },
        use: (_) => use.cont,
      ).run(()).cancel();

      expect(seen, isA<ElseBracketOutcome<String, int>>());
      expect(
        (seen as ElseBracketOutcome<String, int>).error,
        equals('cancelled'),
      );
    });

    test(
        'a cancel during acquire reaches acquire; when acquire '
        'completes, use is cancelled at once and then released',
        () {
      final acquire = _Leaf<Never, int>();
      final use = _Leaf<String, int>()
        ..reportsCancel = true;
      final log = <String>[];
      final token = Cont.bracket<int, (), String, int>(
        acquire: acquire.cont,
        release: (_, __) => _release(log),
        use: (_) => use.cont,
      ).run(());
      token.cancel();

      expect(acquire.cancels, equals(1));
      expect(log, isEmpty);

      acquire.observer!.onThen(1);

      expect(use.cancels, equals(1));
      expect(log, equals(['release']));
    });

    test('a cancel after use finished releases once', () {
      final use = _Leaf<String, int>();
      var releases = 0;
      final token = Cont.bracket<int, (), String, int>(
        acquire: Cont.of(1),
        release: (_, __) {
          releases++;
          return Cont.of(());
        },
        use: (_) => use.cont,
      ).run(());
      use.observer!.onThen(2);
      token.cancel();

      expect(use.cancels, equals(0));
      expect(releases, equals(1));
    });

    test(
        'a cancel reaches a running release: its leaf decides',
        () {
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

    test(
        'a use that ignores the cancel and finishes later is '
        'released, then reported', () {
      final use = _Leaf<String, int>();
      var releases = 0;
      int? value;
      Cont.bracket<int, (), String, int>(
        acquire: Cont.of(1),
        release: (_, __) {
          releases++;
          return Cont.of(());
        },
        use: (_) => use.cont,
      ).run((), onThen: (v) => value = v).cancel();
      use.observer!.onThen(2);

      expect(releases, equals(1));
      expect(value, equals(2));
    });
  });
}
