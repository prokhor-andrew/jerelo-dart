import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.thenTap', () {
    test('executes side-effect and returns original value',
        () {
      bool sideEffectRan = false;
      int? result;

      Cont.of<(), String, int>(42).thenTap((v) {
        sideEffectRan = true;
        return Cont.of(v * 2);
      }).run((), onThen: (v) => result = v);

      expect(sideEffectRan, isTrue);
      expect(result, equals(42));
    });

    test('passes through error', () {
      bool sideEffectRan = false;
      String? error;

      Cont.error<(), String, int>('oops').thenTap((v) {
        sideEffectRan = true;
        return Cont.of(v);
      }).run((), onElse: (e) => error = e);

      expect(sideEffectRan, isFalse);
      expect(error, equals('oops'));
    });

    test('propagates side-effect error', () {
      String? error;

      Cont.of<(), String, int>(42)
          .thenTap((_) => Cont.error<(), String, int>(
              'side-effect failed'))
          .run((), onElse: (e) => error = e);

      expect(error, equals('side-effect failed'));
    });

    test('supports chaining with other operations', () {
      final log = <String>[];
      int? result;

      Cont.of<(), String, int>(1)
          .thenTap((v) {
            log.add('tap:$v');
            return Cont.of(v);
          })
          .thenMap((v) => v + 1)
          .run((), onThen: (v) => result = v);

      expect(log, equals(['tap:1']));
      expect(result, equals(2));
    });

    test('can be run multiple times', () {
      int tapCount = 0;
      final cont =
          Cont.of<(), String, int>(42).thenTap((v) {
        tapCount++;
        return Cont.of(v);
      });

      cont.run(());
      cont.run(());

      expect(tapCount, equals(2));
    });

    test('crashes when function throws', () {
      ContCrash? crash;
      Cont.of<(), String, int>(42)
          .thenTap<int>((v) => throw Exception('boom'))
          .run(
        (),
        onCrash: (c) => crash = c,
        onPanic: (_) {},
      );
      expect(crash, isA<NormalCrash>());
    });
  });

  group('Cont.thenTap0', () {
    test('executes side-effect ignoring value', () {
      bool sideEffectRan = false;
      int? result;

      Cont.of<(), String, int>(42).thenTap0(() {
        sideEffectRan = true;
        return Cont.of(0);
      }).run((), onThen: (v) => result = v);

      expect(sideEffectRan, isTrue);
      expect(result, equals(42));
    });
  });
}
