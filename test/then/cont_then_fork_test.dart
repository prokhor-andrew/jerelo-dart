import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.thenFork', () {
    test('executes side-effect and returns original value',
        () {
      bool sideEffectRan = false;
      int? result;

      Cont.of<(), String, int>(42).thenFork((v) {
        sideEffectRan = true;
        return Cont.of(v * 2);
      }).run((), onThen: (v) => result = v);

      expect(sideEffectRan, isTrue);
      expect(result, equals(42));
    });

    test('passes through error', () {
      bool sideEffectRan = false;
      String? error;

      Cont.error<(), String, int>('oops').thenFork((v) {
        sideEffectRan = true;
        return Cont.of(v);
      }).run((), onElse: (e) => error = e);

      expect(sideEffectRan, isFalse);
      expect(error, equals('oops'));
    });

    test('does not propagate side-effect error', () {
      String? error;
      int? result;

      Cont.of<(), String, int>(42)
          .thenFork((_) => Cont.error<(), String, int>(
              'side-effect error'))
          .run(
        (),
        onThen: (v) => result = v,
        onElse: (e) => error = e,
      );

      expect(result, equals(42));
      expect(error, isNull);
    });

    test('supports fire-and-forget semantics', () {
      final log = <String>[];

      Cont.of<(), String, int>(1).thenFork((v) {
        log.add('fork');
        return Cont.of(v);
      }).thenMap((v) {
        log.add('main');
        return v;
      }).run(());

      expect(log.contains('fork'), isTrue);
      expect(log.contains('main'), isTrue);
    });

    test('can be run multiple times', () {
      int sideEffectCount = 0;
      final cont =
          Cont.of<(), String, int>(42).thenFork((v) {
        sideEffectCount++;
        return Cont.of(v);
      });

      cont.run(());
      cont.run(());

      expect(sideEffectCount, equals(2));
    });
  });

  group('Cont.thenFork0', () {
    test('executes side-effect ignoring value', () {
      bool sideEffectRan = false;
      int? result;

      Cont.of<(), String, int>(42).thenFork0(() {
        sideEffectRan = true;
        return Cont.of(0);
      }).run((), onThen: (v) => result = v);

      expect(sideEffectRan, isTrue);
      expect(result, equals(42));
    });
  });
}
