import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.error', () {
    test('Cont.error calls onElse with provided error', () {
      String? receivedError;
      final cont = Cont.error<(), String, int>('test error');

      cont.run((), onElse: (e) => receivedError = e);
      expect(receivedError, 'test error');
    });

    test('Cont.error does not call onThen', () {
      final cont = Cont.error<(), String, int>('err');

      cont.run(
        (),
        onThen: (_) {
          fail('Should not be called');
        },
      );
    });

    test('Cont.error does not call onCrash', () {
      final cont = Cont.error<(), String, int>('err');

      cont.run(
        (),
        onCrash: (_) {
          fail('Should not be called');
        },
      );
    });

    test('Cont.error does not call onPanic', () {
      final cont = Cont.error<(), String, int>('err');

      cont.run(
        (),
        onPanic: (_) {
          fail('Should not be called');
        },
      );
    });

    test('Cont.error can be run multiple times', () {
      var callCount = 0;
      final cont = Cont.error<(), String, int>('err');

      cont.run((), onElse: (_) => callCount++);
      cont.run((), onElse: (_) => callCount++);

      expect(callCount, 2);
    });

    test('Cont.error works with Never value type', () {
      String? receivedError;
      final cont = Cont.error<(), String, Never>('err');

      cont.run(
        (),
        onElse: (e) => receivedError = e,
        onThen: (_) {
          fail('Should not be called');
        },
      );
      expect(receivedError, 'err');
    });
  });
}
