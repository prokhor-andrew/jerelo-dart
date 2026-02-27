import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.thenDo', () {
    test('chains successful values', () {
      int? result;
      Cont.of<(), String, int>(1)
          .thenDo((v) => Cont.of(v + 1))
          .run((), onThen: (v) => result = v);
      expect(result, equals(2));
    });

    test('passes through error', () {
      String? error;
      Cont.error<(), String, int>('oops')
          .thenDo((v) => Cont.of(v + 1))
          .run((), onElse: (e) => error = e);
      expect(error, equals('oops'));
    });

    test('chains to new error', () {
      String? error;
      Cont.of<(), String, int>(42)
          .thenDo(
              (_) => Cont.error<(), String, int>('failed'))
          .run((), onElse: (e) => error = e);
      expect(error, equals('failed'));
    });

    test('supports type transformation', () {
      String? result;
      Cont.of<(), String, int>(42)
          .thenDo((v) => Cont.of(v.toString()))
          .run((), onThen: (v) => result = v);
      expect(result, equals('42'));
    });

    test('supports multiple chaining', () {
      int? result;
      Cont.of<(), String, int>(1)
          .thenDo((v) => Cont.of(v + 1))
          .thenDo((v) => Cont.of(v * 10))
          .run((), onThen: (v) => result = v);
      expect(result, equals(20));
    });

    test('can be run multiple times', () {
      final cont = Cont.of<(), String, int>(5)
          .thenDo((v) => Cont.of(v * 2));

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
          .thenDo((v) => throw Exception('boom'))
          .run(
        (),
        onCrash: (c) => crash = c,
        onPanic: (_) {},
      );
      expect(crash, isA<NormalCrash>());
    });
  });

  group('Cont.thenDo0', () {
    test('chains without value', () {
      int? result;
      Cont.of<(), String, int>(99)
          .thenDo0(() => Cont.of(0))
          .run((), onThen: (v) => result = v);
      expect(result, equals(0));
    });
  });
}
