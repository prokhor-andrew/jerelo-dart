import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.of', () {
    test('Cont.of is run correctly', () {
      var value = 15;
      final cont = Cont.of<(), int>(0);

      expect(value, 15);
      cont.run((), onThen: (val) => value = val);
      expect(value, 0);
    });

    test('Cont.of does not call onElse', () {
      final cont = Cont.of<(), int>(0);

      cont.run(
        (),
        onElse: (_) {
          fail('Should not be called');
        },
        onThen: (_) {},
      );
    });

    test('Cont.of does not call onPanic', () {
      final cont = Cont.of<(), int>(0);

      cont.run(
        (),
        onPanic: (_) {
          fail('Should not be called');
        },
        onThen: (_) {},
      );
    });

    test('Cont.of can be run multiple times', () {
      var value = 0;
      final cont = Cont.of<(), int>(15);

      cont.run((), onThen: (val) => value = val);
      expect(value, 15);

      value = 0;
      cont.run((), onThen: (val) => value = val);
      expect(value, 15);
    });
  });
}
