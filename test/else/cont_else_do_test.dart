import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.elseDo', () {
    test('recovers from error', () {
      int? result;

      Cont.error<(), String, int>('oops')
          .elseDo((_) => Cont.of(42))
          .run((), onThen: (v) => result = v);

      expect(result, equals(42));
    });

    test('receives original error', () {
      String? captured;
      int? result;

      Cont.error<(), String, int>('original').elseDo((e) {
        captured = e;
        return Cont.of(0);
      }).run((), onThen: (v) => result = v);

      expect(captured, equals('original'));
      expect(result, equals(0));
    });

    test('propagates only fallback error when both fail',
        () {
      String? error;

      Cont.error<(), String, int>('first')
          .elseDo(
              (_) => Cont.error<(), String, int>('second'))
          .run((), onElse: (e) => error = e);

      expect(error, equals('second'));
    });

    test('never executes on value path', () {
      bool called = false;
      int? result;

      Cont.of<(), String, int>(42).elseDo((_) {
        called = true;
        return Cont.of(0);
      }).run((), onThen: (v) => result = v);

      expect(called, isFalse);
      expect(result, equals(42));
    });

    test('crashes when fallback builder throws', () {
      ContCrash? crash;

      Cont.error<(), String, int>('oops')
          .elseDo<String>((_) => throw Exception('boom'))
          .run(
        (),
        onCrash: (c) => crash = c,
        onPanic: (_) {},
      );

      expect(crash, isA<NormalCrash>());
    });

    test('supports type transformation', () {
      int? result;

      Cont.error<(), String, int>('oops')
          .elseDo<Never>((_) => Cont.of(99))
          .run((), onThen: (v) => result = v);

      expect(result, equals(99));
    });

    test('can be run multiple times', () {
      int? first;
      int? second;

      final cont = Cont.error<(), String, int>('err')
          .elseDo((_) => Cont.of(42));

      cont.run((), onThen: (v) => first = v);
      cont.run((), onThen: (v) => second = v);

      expect(first, equals(42));
      expect(second, equals(42));
    });
  });

  group('Cont.elseDo0', () {
    test('recovers without error value', () {
      int? result;

      Cont.error<(), String, int>('oops')
          .elseDo0(() => Cont.of(99))
          .run((), onThen: (v) => result = v);

      expect(result, equals(99));
    });
  });
}
