import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.local0', () {
    test('provides constant environment', () {
      int? result;

      Cont.askThen<int, Never>()
          .local0<String>(() => 42)
          .run('ignored', onThen: (v) => result = v);

      expect(result, equals(42));
    });
  });

  group('Cont.withEnv', () {
    test('provides fixed environment', () {
      int? result;

      Cont.askThen<int, Never>()
          .withEnv<String>(99)
          .run('ignored', onThen: (v) => result = v);

      expect(result, equals(99));
    });
  });
}
