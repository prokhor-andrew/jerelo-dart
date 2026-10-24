import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.elseMap0', () {
    test('maps without error value', () {
      String? error;

      Cont.error<(), String, int>('original')
          .elseMap0(() => 'replaced')
          .run((), onElse: (e) => error = e);

      expect(error, equals('replaced'));
    });
  });

  group('Cont.elseMapTo', () {
    test('replaces with constant error', () {
      int? error;

      Cont.error<(), String, int>('original')
          .elseMapTo(99)
          .run((), onElse: (e) => error = e);

      expect(error, equals(99));
    });
  });
}
