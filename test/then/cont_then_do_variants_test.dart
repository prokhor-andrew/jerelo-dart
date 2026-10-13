import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.thenDo0', () {
    test('chains without value', () {
      int? result;
      Cont.of<(), String, int>(99)
          .thenDo0(() => Cont.of(0))
          .run((), onThen: (v) => result = v);
      expect(result, equals(0));
    });
  });
}
