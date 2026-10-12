import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.thenUnit', () {
    test('replaces the value with ()', () {
      Object? result;

      Cont.of<(), String, int>(42)
          .thenUnit()
          .run((), onThen: (v) => result = v);

      expect(result, equals(()));
    });

    test('keeps the error', () {
      String? error;

      Cont.error<(), String, int>('oops')
          .thenUnit()
          .run((), onElse: (e) => error = e);

      expect(error, equals('oops'));
    });
  });

  group('Cont.elseUnit', () {
    test('replaces the error with ()', () {
      Object? error;

      Cont.error<(), String, int>('oops')
          .elseUnit()
          .run((), onElse: (e) => error = e);

      expect(error, equals(()));
    });

    test('keeps the value', () {
      int? result;

      Cont.of<(), String, int>(42)
          .elseUnit()
          .run((), onThen: (v) => result = v);

      expect(result, equals(42));
    });
  });
}
