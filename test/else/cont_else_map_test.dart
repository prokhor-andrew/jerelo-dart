import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.elseMap', () {
    test('maps error value', () {
      int? error;

      Cont.error<(), String, int>('42')
          .elseMap((e) => int.parse(e))
          .run((), onElse: (e) => error = e);

      expect(error, equals(42));
    });

    test('passes through value', () {
      int? result;
      bool elseCalled = false;

      Cont.of<(), String, int>(42)
          .elseMap((e) => 'mapped:$e')
          .run(
        (),
        onThen: (v) => result = v,
        onElse: (_) => elseCalled = true,
      );

      expect(result, equals(42));
      expect(elseCalled, isFalse);
    });

    test('supports type transformation', () {
      int? error;

      Cont.error<(), String, int>('99')
          .elseMap((e) => int.parse(e))
          .run((), onElse: (e) => error = e);

      expect(error, equals(99));
    });

    test('supports multiple mapping', () {
      String? error;

      Cont.error<(), String, int>('hello')
          .elseMap((e) => e.toUpperCase())
          .elseMap((e) => '$e!')
          .run((), onElse: (e) => error = e);

      expect(error, equals('HELLO!'));
    });

    test('can be run multiple times', () {
      String? first;
      String? second;

      final cont = Cont.error<(), String, int>('err')
          .elseMap((e) => '$e-mapped');

      cont.run((), onElse: (e) => first = e);
      cont.run((), onElse: (e) => second = e);

      expect(first, equals('err-mapped'));
      expect(second, equals('err-mapped'));
    });

    test('crashes when function throws', () {
      ContCrash? crash;

      Cont.error<(), String, int>('oops')
          .elseMap<int>((e) => throw Exception('boom'))
          .run(
        (),
        onCrash: (c) => crash = c,
        onPanic: (_) {},
      );

      expect(crash, isA<NormalCrash>());
    });
  });

  group('Cont.elseMap0', () {
    test('maps without error value', () {
      String? error;

      Cont.error<(), String, int>('original')
          .elseMap0(() => 'replaced')
          .run((), onElse: (e) => error = e);

      expect(error, equals('replaced'));
    });
  });

  group('Cont.elseMapTo', () {
    test('replaces with constant error', () {
      int? error;

      Cont.error<(), String, int>('original')
          .elseMapTo(99)
          .run((), onElse: (e) => error = e);

      expect(error, equals(99));
    });
  });
}
