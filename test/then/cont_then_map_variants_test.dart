import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.thenMap0', () {
    test('maps without value', () {
      String? result;
      Cont.of<(), String, int>(99)
          .thenMap0(() => 'replaced')
          .run((), onThen: (v) => result = v);
      expect(result, equals('replaced'));
    });
  });

  group('Cont.thenMapTo', () {
    test('replaces with constant value', () {
      String? result;
      Cont.of<(), String, int>(99)
          .thenMapTo('constant')
          .run((), onThen: (v) => result = v);
      expect(result, equals('constant'));
    });
  });

  group('Cont.thenMapWithEnv', () {
    test('maps with environment and value', () {
      String? result;
      Cont.of<String, Never, int>(10)
          .thenMapWithEnv((env, v) => '$env:$v')
          .run('env', onThen: (v) => result = v);
      expect(result, equals('env:10'));
    });
  });
}
