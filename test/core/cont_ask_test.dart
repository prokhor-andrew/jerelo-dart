import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.askThen', () {
    test('Cont.askThen triggers onThen with same value', () {
      final cont = Cont.askThen<int, String>();

      var value = 0;

      expect(value, 0);

      cont.run(
        5,
        onThen: (val) {
          value = val;
        },
      );

      expect(value, 5);
    });

    test('Cont.askThen triggers onThen with same null', () {
      final cont = Cont.askThen<int?, String>();

      int? value = 0;

      expect(value, 0);

      cont.run(
        null,
        onThen: (val) {
          value = val;
        },
      );

      expect(value, null);
    });

    test('Cont.askThen preserves environment identity', () {
      final env = [1, 2, 3];
      final cont = Cont.askThen<List<int>, String>();

      Object? received;

      cont.run(
        env,
        onThen: (val) {
          received = val;
        },
      );

      expect(identical(env, received), isTrue);
    });

    test('Cont.askThen does not trigger onElse', () {
      final cont = Cont.askThen<int, String>();

      cont.run(
        5,
        onElse: (_) {
          fail('Must not be called');
        },
      );
    });

    test('Cont.askThen does not trigger onPanic', () {
      final cont = Cont.askThen<int, String>();

      cont.run(
        5,
        onPanic: (_) {
          fail('Must not be called');
        },
      );
    });

    test('Cont.askThen can be run multiple times', () {
      var callCount = 0;
      final cont = Cont.askThen<int, String>();

      cont.run(0, onThen: (_) => callCount++);
      cont.run(0, onThen: (_) => callCount++);

      expect(callCount, 2);
    });
  });

  group('Cont.askElse', () {
    test('Cont.askElse triggers onElse with environment', () {
      final cont = Cont.askElse<int, int>();

      int? error;

      cont.run(
        5,
        onElse: (val) {
          error = val;
        },
      );

      expect(error, 5);
    });

    test('Cont.askElse does not trigger onThen', () {
      final cont = Cont.askElse<int, int>();

      cont.run(
        5,
        onThen: (_) {
          fail('Must not be called');
        },
      );
    });
  });
}
