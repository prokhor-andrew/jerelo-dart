import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont variance', () {
    test('both with untyped quitFast policy runs', () {
      final Cont<(), String, int> left = Cont.of(1);
      final Cont<(), String, int> right = Cont.of(2);
      int? result;
      ContCrash? crash;

      Cont.both(
        left,
        right,
        (int a, int b) => a + b,
        policy: OkPolicy.quitFast(),
      ).run(
        (),
        onCrash: (c) => crash = c,
        onThen: (v) => result = v,
      );

      expect(crash, isNull);
      expect(result, equals(3));
    });

    test('coalesce with untyped quitFast policy runs', () {
      final Cont<(), String, int> left = Cont.of(1);
      final Cont<(), String, int> right = Cont.of(2);
      Object? result;
      ContCrash? crash;

      Cont.coalesce(
        left,
        right,
        policy: CrashPolicy.quitFast(),
      ).run(
        (),
        onCrash: (c) => crash = c,
        onThen: (v) => result = v,
      );

      expect(crash, isNull);
      expect(result, equals(1));
    });

    test('both runs inputs upcast to dynamic', () {
      final Cont<(), dynamic, dynamic> left =
          Cont.of<(), String, int>(1);
      final Cont<(), dynamic, dynamic> right =
          Cont.of<(), String, int>(2);
      Object? result;
      ContCrash? crash;

      Cont.both(
        left,
        right,
        (a, b) => '$a+$b',
        policy: OkPolicy.quitFast(),
      ).run(
        (),
        onCrash: (c) => crash = c,
        onThen: (v) => result = v,
      );

      expect(crash, isNull);
      expect(result, equals('1+2'));
    });

    test('operators run on a value upcast to a wider type',
        () {
      final Cont<(), Object?, Object?> wide =
          Cont.of<(), String, int>(1);
      Object? result;
      ContCrash? crash;

      wide.thenMap((v) => '$v!').run(
        (),
        onCrash: (c) => crash = c,
        onThen: (v) => result = v,
      );

      expect(crash, isNull);
      expect(result, equals('1!'));
    });

    test('errors pass through a wider type', () {
      final Cont<(), Object?, int> wide =
          Cont.error<(), String, int>('oops');
      Object? error;
      ContCrash? crash;

      wide.elseMap((e) => '$e!').run(
        (),
        onCrash: (c) => crash = c,
        onElse: (e) => error = e,
      );

      expect(crash, isNull);
      expect(error, equals('oops!'));
    });

    test('operators run on a Never-typed error upcast', () {
      final Cont<(), Never, int> never = Cont.of(1);
      final Cont<(), String, int> upcast = never;
      int? result;
      ContCrash? crash;

      upcast.elseMap((e) => '$e!').run(
        (),
        onCrash: (c) => crash = c,
        onThen: (v) => result = v,
      );

      expect(crash, isNull);
      expect(result, equals(1));
    });

    test('operators run on a Never-typed value upcast', () {
      final Cont<(), String, Never> never =
          Cont.error('oops');
      final Cont<(), String, int> upcast = never;
      String? error;
      ContCrash? crash;

      upcast.thenMap((v) => v + 1).run(
        (),
        onCrash: (c) => crash = c,
        onElse: (e) => error = e,
      );

      expect(crash, isNull);
      expect(error, equals('oops'));
    });

    test('policy without type arguments infers types', () {
      final Cont<(), String, int> left = Cont.of(1);
      final Cont<(), String, int> right = Cont.of(2);
      int? result;

      Cont.both(
        left,
        right,
        (int a, int b) => a + b,
        policy: OkPolicy.quitFast(),
      ).run((), onThen: (v) => result = v);

      expect(result, equals(3));
    });
  });
}
