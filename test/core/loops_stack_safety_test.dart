import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

const iterations = 100000;

void main() {
  group('Loops are stack safe for synchronous steps', () {
    test('thenWhile', () {
      var count = 0;
      int? result;

      Cont.fromDeferred<(), String, int>(
              () => Cont.of(++count))
          .thenWhile((n) => n < iterations)
          .run((), onThen: (v) => result = v);

      expect(result, equals(iterations));
    });

    test('elseWhile', () {
      var count = 0;
      int? error;

      Cont.fromDeferred<(), int, String>(
              () => Cont.error(++count))
          .elseWhile((n) => n < iterations)
          .run((), onElse: (e) => error = e);

      expect(error, equals(iterations));
    });

    test('crashWhile', () {
      var count = 0;
      ContCrash? crash;

      Cont.fromDeferred<(), String, int>(() {
        count++;
        return Cont.of<(), String, int>(0).thenDo((_) {
          throw count;
        });
      })
          .crashWhile((_) => count < iterations)
          .run((), onCrash: (c) => crash = c);

      expect((crash! as NormalCrash).error,
          equals(iterations));
    });
  });
}
