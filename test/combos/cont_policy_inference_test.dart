import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Policy factories without type arguments', () {
    final Cont<(), String, int> left = Cont.of(1);
    final Cont<(), String, int> right = Cont.of(2);

    test('OkPolicy.sequence lets both infer F', () {
      final cont = Cont.both(
        left,
        right,
        (int a, int b) => a + b,
        policy: OkPolicy.sequence(),
      );

      expect(cont, isA<Cont<(), String, int>>());
    });

    test('OkPolicy.quitFast lets both infer F', () {
      final cont = Cont.both(
        left,
        right,
        (int a, int b) => a + b,
        policy: OkPolicy.quitFast(),
      );

      expect(cont, isA<Cont<(), String, int>>());
    });

    test('OkPolicy.quitFast lets either infer A', () {
      final cont = Cont.either(
        left,
        right,
        (String a, String b) => '$a, $b',
        policy: OkPolicy.quitFast(),
      );

      expect(cont, isA<Cont<(), String, int>>());
    });

    test('OkPolicy.sequence lets all infer F', () {
      final cont = Cont.all(
        [left, right],
        policy: OkPolicy.sequence(),
      );

      expect(cont, isA<Cont<(), String, List<int>>>());
    });

    test('OkPolicy.quitFast lets any infer A', () {
      final cont = Cont.any(
        [left, right],
        policy: OkPolicy.quitFast(),
      );

      expect(cont, isA<Cont<(), List<String>, int>>());
    });

    test('CrashPolicy.sequence lets coalesce infer F and A',
        () {
      final cont = Cont.coalesce(
        left,
        right,
        policy: CrashPolicy.sequence(),
      );

      expect(cont, isA<Cont<(), String, int>>());
    });

    test('CrashPolicy.quitFast lets converge infer F and A',
        () {
      final cont = Cont.converge(
        [left, right],
        policy: CrashPolicy.quitFast(),
      );

      expect(cont, isA<Cont<(), String, int>>());
    });

    test('inferred error type reaches onElse as String',
        () {
      final Cont<(), String, int> failing =
          Cont.error('oops');
      String? error;

      Cont.both(
        failing,
        right,
        (int a, int b) => a + b,
        policy: OkPolicy.quitFast(),
      ).elseMap((e) => e.toUpperCase()).run(
        (),
        onElse: (e) => error = e,
      );

      expect(error, equals('OOPS'));
    });
  });
}
