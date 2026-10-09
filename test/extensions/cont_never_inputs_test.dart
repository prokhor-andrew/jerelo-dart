import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

// Never-typed continuations passed where a wider type is expected.
// Each test goes through a different kind of operator that used to
// call absurdify() on its input.
final Cont<(), Never, int> neverFails = Cont.of(1);
final Cont<(), String, Never> neverSucceeds =
    Cont.error('oops');

void main() {
  group('Never-typed inputs', () {
    test('both', () {
      String? error;
      ContCrash? crash;

      Cont.both<(), String, int, int, int>(
        neverFails,
        neverSucceeds,
        (a, b) => a + b,
        policy: OkPolicy.quitFast(),
      ).run(
        (),
        onCrash: (c) => crash = c,
        onElse: (e) => error = e,
      );

      expect(crash, isNull);
      expect(error, equals('oops'));
    });

    test('either', () {
      int? result;
      ContCrash? crash;

      Cont.either<(), String, String, String, int>(
        neverSucceeds,
        neverFails,
        (a, b) => '$a$b',
        policy: OkPolicy.sequence(),
      ).run(
        (),
        onCrash: (c) => crash = c,
        onThen: (v) => result = v,
      );

      expect(crash, isNull);
      expect(result, equals(1));
    });

    test('coalesce', () {
      int? result;
      ContCrash? crash;

      Cont.coalesce<(), String, int>(
        neverFails,
        neverSucceeds,
        policy: CrashPolicy.sequence(),
      ).run(
        (),
        onCrash: (c) => crash = c,
        onThen: (v) => result = v,
      );

      expect(crash, isNull);
      expect(result, equals(1));
    });

    for (final policy in [
      OkPolicy.sequence(),
      OkPolicy.quitFast(),
      OkPolicy.runAll<String>(
        (a, b) => a + b,
        shouldFavorCrash: true,
      ),
    ]) {
      test('all with ${policy.runtimeType}', () {
        List<int>? result;
        ContCrash? crash;

        Cont.all<(), String, int>(
          [neverFails, neverFails],
          policy: policy,
        ).run(
          (),
          onCrash: (c) => crash = c,
          onThen: (v) => result = v,
        );

        expect(crash, isNull);
        expect(result, equals([1, 1]));
      });
    }

    for (final policy in [
      CrashPolicy.sequence(),
      CrashPolicy.quitFast(),
      CrashPolicy.runAll<String, int>(
        shouldFavorElse: true,
        combineElseVals: (a, b) => a + b,
        combineThenVals: (a, b) => a + b,
      ),
    ]) {
      test('converge with ${policy.runtimeType}', () {
        Object? result;
        ContCrash? crash;

        Cont.converge<(), String, int>(
          [neverFails, neverSucceeds],
          policy: policy,
        ).run(
          (),
          onCrash: (c) => crash = c,
          onThen: (v) => result = v,
          onElse: (e) => result = e,
        );

        expect(crash, isNull);
        expect(result, isNotNull);
      });
    }

    test('thenDo, elseDo and crashDo', () {
      int? result;
      ContCrash? crash;

      Cont.of<(), String, int>(0)
          .thenDo<int>((_) => neverSucceeds)
          .elseDo<String>((_) => neverFails)
          .thenDo<int>((_) => throw 'boom')
          .crashDo((_) => neverFails)
          .run(
        (),
        onCrash: (c) => crash = c,
        onThen: (v) => result = v,
      );

      expect(crash, isNull);
      expect(result, equals(1));
    });

    test('fromDeferred', () {
      int? result;

      Cont.fromDeferred<(), String, int>(() => neverFails)
          .run((), onThen: (v) => result = v);

      expect(result, equals(1));
    });

    test('thenInject', () {
      int? result;
      ContCrash? crash;

      final Cont<String, Never, int> needsEnv = Cont.of(5);

      Cont.of<(), Never, String>('env')
          .thenInject(needsEnv)
          .run(
        (),
        onCrash: (c) => crash = c,
        onThen: (v) => result = v,
      );

      expect(crash, isNull);
      expect(result, equals(5));
    });
  });
}
