import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.elseFork', () {
    test('executes side-effect and returns original error',
        () {
      bool sideEffectRan = false;
      String? error;

      Cont.error<(), String, int>('oops').elseFork((e) {
        sideEffectRan = true;
        return Cont.of(0);
      }).run((), onElse: (e) => error = e);

      expect(sideEffectRan, isTrue);
      expect(error, equals('oops'));
    });

    test('passes through value', () {
      bool called = false;
      int? result;

      Cont.of<(), String, int>(42).elseFork((_) {
        called = true;
        return Cont.of(0);
      }).run((), onThen: (v) => result = v);

      expect(called, isFalse);
      expect(result, equals(42));
    });

    test('does not propagate side-effect error', () {
      String? error;
      int? result;

      Cont.error<(), String, int>('original')
          .elseFork((_) => Cont.error<(), String, int>(
              'side-effect error'))
          .run(
        (),
        onElse: (e) => error = e,
        onThen: (v) => result = v,
      );

      expect(error, equals('original'));
      expect(result, isNull);
    });

    test('can be run multiple times', () {
      int sideEffectCount = 0;

      final cont =
          Cont.error<(), String, int>('err').elseFork((e) {
        sideEffectCount++;
        return Cont.of(0);
      });

      cont.run(());
      cont.run(());

      expect(sideEffectCount, equals(2));
    });
  });

  group('Cont.elseFork0', () {
    test('executes side-effect ignoring error', () {
      bool sideEffectRan = false;
      String? error;

      Cont.error<(), String, int>('oops').elseFork0(() {
        sideEffectRan = true;
        return Cont.of(0);
      }).run((), onElse: (e) => error = e);

      expect(sideEffectRan, isTrue);
      expect(error, equals('oops'));
    });
  });
}
