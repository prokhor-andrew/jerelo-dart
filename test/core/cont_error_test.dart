import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.error', () {
    test('Cont.error calls onElse with provided error', () {
      String? result;
      Cont.error<(), String, int>('oops').run(
        (),
        onElse: (e) => result = e,
      );
      expect(result, equals('oops'));
    });

    test('Cont.error does not call onThen', () {
      bool thenCalled = false;
      Cont.error<(), String, int>('oops').run(
        (),
        onThen: (_) => thenCalled = true,
      );
      expect(thenCalled, isFalse);
    });

    test('Cont.error does not call onCrash', () {
      bool crashCalled = false;
      Cont.error<(), String, int>('oops').run(
        (),
        onCrash: (_) => crashCalled = true,
      );
      expect(crashCalled, isFalse);
    });

    test('Cont.error does not call onPanic', () {
      bool panicCalled = false;
      Cont.error<(), String, int>('oops').run(
        (),
        onPanic: (_) => panicCalled = true,
      );
      expect(panicCalled, isFalse);
    });

    test('Cont.error can be run multiple times', () {
      final cont = Cont.error<(), String, int>('oops');

      String? first;
      String? second;
      cont.run((), onElse: (e) => first = e);
      cont.run((), onElse: (e) => second = e);

      expect(first, equals('oops'));
      expect(second, equals('oops'));
    });

    test('Cont.error works with Never value type', () {
      String? result;
      Cont.error<(), String, Never>('oops').run(
        (),
        onElse: (e) => result = e,
      );
      expect(result, equals('oops'));
    });
  });
}
