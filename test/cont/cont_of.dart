
import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.of', () {
    test('Cont.of is run correctly', () {
      var value = 15;
      final cont = Cont.of<(), int>(0);

      expect(value, 15);
      cont.run((), onValue: (val) => value = val);
      expect(value, 0);
    });

    test('Cont.of does not call onTerminate', () {
      final cont = Cont.of<(), int>(0);

      cont.run(
        (),
        onTerminate: (_) {
          fail('Should not be called');
        },
        onValue: (_) {},
      );
    });

    test('Cont.of does not call onPanic', () {
      final cont = Cont.of<(), int>(0);

      cont.run(
        (),
        onPanic: (_) {
          fail('Should not be called');
        },
        onValue: (_) {},
      );
    });

    test('Cont.of can be run multiple times', () {
      var value = 0;
      final cont = Cont.of<(), int>(15);

      cont.run((), onValue: (val) => value = val);
      expect(value, 15);

      value = 0;
      cont.run((), onValue: (val) => value = val);
      expect(value, 15);
    });

    test('Cont.of with null value', () {
      String? value = 'initial';
      final cont = Cont.of<(), String?>(null);

      cont.run((), onValue: (val) => value = val);
      expect(value, null);
    });
  });
}