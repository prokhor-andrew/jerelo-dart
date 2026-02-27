import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.elseTap', () {
    test('promotes to success when side-effect succeeds',
        () {
      int? result;

      Cont.error<(), String, int>('oops')
          .elseTap((_) => Cont.of(42))
          .run((), onThen: (v) => result = v);

      expect(result, equals(42));
    });

    test('passes through value', () {
      bool called = false;
      int? result;

      Cont.of<(), String, int>(42).elseTap((_) {
        called = true;
        return Cont.of(0);
      }).run((), onThen: (v) => result = v);

      expect(called, isFalse);
      expect(result, equals(42));
    });

    test('keeps original error when side-effect fails', () {
      String? error;

      Cont.error<(), String, int>('original')
          .elseTap((_) => Cont.error<(), String, int>(
              'side-effect error'))
          .run((), onElse: (e) => error = e);

      expect(error, equals('original'));
    });

    test('can be run multiple times', () {
      int tapCount = 0;
      final cont =
          Cont.error<(), String, int>('oops').elseTap((_) {
        tapCount++;
        return Cont.of(0);
      });

      cont.run(());
      cont.run(());

      expect(tapCount, equals(2));
    });

    test('crashes when function throws', () {
      ContCrash? crash;

      Cont.error<(), String, int>('oops')
          .elseTap<int>((_) => throw Exception('boom'))
          .run(
        (),
        onCrash: (c) => crash = c,
        onPanic: (_) {},
      );

      expect(crash, isA<NormalCrash>());
    });
  });

  group('Cont.elseTap0', () {
    test(
        'promotes when side-effect succeeds ignoring error',
        () {
      int? result;

      Cont.error<(), String, int>('oops')
          .elseTap0(() => Cont.of(99))
          .run((), onThen: (v) => result = v);

      expect(result, equals(99));
    });
  });
}
