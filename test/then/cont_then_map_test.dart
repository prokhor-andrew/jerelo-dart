import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.thenMap', () {
    test('maps successful value', () {
      int? result;
      Cont.of<(), String, int>(21)
          .thenMap((v) => v * 2)
          .run((), onThen: (v) => result = v);
      expect(result, equals(42));
    });

    test('passes through error', () {
      String? error;
      Cont.error<(), String, int>('oops')
          .thenMap((v) => v * 2)
          .run((), onElse: (e) => error = e);
      expect(error, equals('oops'));
    });

    test('supports type transformation', () {
      String? result;
      Cont.of<(), String, int>(42)
          .thenMap((v) => v.toString())
          .run((), onThen: (v) => result = v);
      expect(result, equals('42'));
    });

    test('supports multiple mapping', () {
      int? result;
      Cont.of<(), String, int>(1)
          .thenMap((v) => v + 1)
          .thenMap((v) => v * 10)
          .run((), onThen: (v) => result = v);
      expect(result, equals(20));
    });

    test('can be run multiple times', () {
      final cont =
          Cont.of<(), String, int>(5).thenMap((v) => v * 2);

      int? first;
      int? second;
      cont.run((), onThen: (v) => first = v);
      cont.run((), onThen: (v) => second = v);

      expect(first, equals(10));
      expect(second, equals(10));
    });

    test('crashes when function throws', () {
      ContCrash? crash;
      Cont.of<(), String, int>(42)
          .thenMap<int>((v) => throw Exception('boom'))
          .run(
        (),
        onCrash: (c) => crash = c,
        onPanic: (_) {},
      );
      expect(crash, isA<NormalCrash>());
    });
  });

  group('Cont.thenMap0', () {
    test('maps without value', () {
      String? result;
      Cont.of<(), String, int>(99)
          .thenMap0(() => 'replaced')
          .run((), onThen: (v) => result = v);
      expect(result, equals('replaced'));
    });
  });

  group('Cont.thenMapTo', () {
    test('replaces with constant value', () {
      String? result;
      Cont.of<(), String, int>(99)
          .thenMapTo('constant')
          .run((), onThen: (v) => result = v);
      expect(result, equals('constant'));
    });
  });

  group('Cont.thenMapWithEnv', () {
    test('maps with environment and value', () {
      String? result;
      Cont.of<String, Never, int>(10)
          .thenMapWithEnv((env, v) => '$env:$v')
          .run('env', onThen: (v) => result = v);
      expect(result, equals('env:10'));
    });
  });
}
