import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.ask', () {
    test('Cont.ask triggers onValue with same value', () {
      final cont = Cont.ask<int>();

      var value = 0;

      expect(value, 0);

      cont.run(
        5,
        onValue: (val) {
          value = val;
        },
      );

      expect(value, 5);
    });

    test('Cont.ask triggers onValue with same null', () {
      final cont = Cont.ask<int?>();

      int? value = 0;

      expect(value, 0);

      cont.run(
        null,
        onValue: (val) {
          value = val;
        },
      );

      expect(value, null);
    });

    test('Cont.ask preserves environment identity', () {
      final env = [1, 2, 3];
      final cont = Cont.ask<List<int>>();

      Object? received;

      cont.run(
        env,
        onValue: (val) {
          received = val;
        },
      );

      expect(identical(env, received), isTrue);
    });

    test('Cont.ask does not trigger onTerminate', () {
      final cont = Cont.ask<int>();

      cont.run(
        5,
        onTerminate: (_) {
          fail('Must not be called');
        },
      );
    });

    test('Cont.ask does not trigger onPanic', () {
      final cont = Cont.ask<int>();

      cont.run(
        5,
        onPanic: (_) {
          fail('Must not be called');
        },
      );
    });

    test('Cont.ask can be run multiple times', () {
      var callCount = 0;
      final cont = Cont.ask<int>();

      cont.run(0, onValue: (_) => callCount++);
      cont.run(0, onValue: (_) => callCount++);

      expect(callCount, 2);
    });
  });
}
