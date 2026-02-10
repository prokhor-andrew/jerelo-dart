import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.of', () {
    test('produces value immediately', () {
      var value = 15;
      final cont = Cont.of<(), int>(0);

      expect(value, 15);
      cont.run((), onValue: (val) => value = val);
      expect(value, 0);
    });

    test('never calls onTerminate', () {
      final cont = Cont.of<(), int>(0);

      cont.run(
        (),
        onTerminate: (_) {
          fail('Should not be called');
        },
        onValue: (_) {},
      );
    });

    test('never calls onPanic', () {
      final cont = Cont.of<(), int>(0);

      cont.run(
        (),
        onPanic: (_) {
          fail('Should not be called');
        },
        onValue: (_) {},
      );
    });

    test('supports multiple runs', () {
      var value = 0;
      final cont = Cont.of<(), int>(15);

      cont.run((), onValue: (val) => value = val);
      expect(value, 15);

      value = 0;
      cont.run((), onValue: (val) => value = val);
      expect(value, 15);
    });

    test('supports null values', () {
      String? value = 'initial';
      final cont = Cont.of<(), String?>(null);

      cont.run((), onValue: (val) => value = val);
      expect(value, null);
    });
  });
}
