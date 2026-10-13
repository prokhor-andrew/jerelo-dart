import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.elseDo0', () {
    test('recovers without error value', () {
      int? result;

      Cont.error<(), String, int>('oops')
          .elseDo0(() => Cont.of(99))
          .run((), onThen: (v) => result = v);

      expect(result, equals(99));
    });
  });
}
