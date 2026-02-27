import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.demote', () {
    test('terminates with computed error from value', () {
      String? error;

      Cont.of<(), String, int>(42)
          .demote((v) => 'value was $v')
          .run((), onElse: (e) => error = e);

      expect(error, equals('value was 42'));
    });

    test('does not call onThen', () {
      bool thenCalled = false;

      Cont.of<(), String, int>(42)
          .demote((_) => 'error')
          .run((), onThen: (_) => thenCalled = true);

      expect(thenCalled, isFalse);
    });

    test('passes through original error', () {
      String? error;

      Cont.error<(), String, int>('original')
          .demote((_) => 'demoted')
          .run((), onElse: (e) => error = e);

      expect(error, equals('original'));
    });

    test('crashes when function throws', () {
      ContCrash? crash;

      Cont.of<(), String, int>(42)
          .demote((_) => throw Exception('boom'))
          .run(
        (),
        onCrash: (c) => crash = c,
        onPanic: (_) {},
      );

      expect(crash, isA<NormalCrash>());
    });

    test('can be run multiple times', () {
      String? first;
      String? second;

      final cont = Cont.of<(), String, int>(42)
          .demote((v) => 'error:$v');

      cont.run((), onElse: (e) => first = e);
      cont.run((), onElse: (e) => second = e);

      expect(first, equals('error:42'));
      expect(second, equals('error:42'));
    });
  });

  group('Cont.demote0', () {
    test('terminates with error ignoring value', () {
      String? error;

      Cont.of<(), String, int>(42)
          .demote0(() => 'fixed error')
          .run((), onElse: (e) => error = e);

      expect(error, equals('fixed error'));
    });
  });

  group('Cont.demoteWith', () {
    test('terminates with constant error', () {
      String? error;

      Cont.of<(), String, int>(42)
          .demoteWith('constant')
          .run((), onElse: (e) => error = e);

      expect(error, equals('constant'));
    });
  });
}
