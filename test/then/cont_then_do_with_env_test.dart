import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.thenDoWithEnv', () {
    test('receives environment and value', () {
      String? capturedEnv;
      int? capturedValue;
      int? result;

      Cont.of<String, Never, int>(10)
          .thenDoWithEnv((env, v) {
        capturedEnv = env;
        capturedValue = v;
        return Cont.of(v + 1);
      }).run('myEnv', onThen: (v) => result = v);

      expect(capturedEnv, equals('myEnv'));
      expect(capturedValue, equals(10));
      expect(result, equals(11));
    });

    test('passes through error', () {
      bool called = false;
      String? error;

      Cont.error<String, String, int>('oops')
          .thenDoWithEnv((env, v) {
        called = true;
        return Cont.of(v);
      }).run('myEnv', onElse: (e) => error = e);

      expect(called, isFalse);
      expect(error, equals('oops'));
    });

    test('can be run multiple times', () {
      int? first;
      int? second;

      final cont =
          Cont.of<int, Never, int>(5).thenDoWithEnv(
        (env, v) => Cont.of(env + v),
      );

      cont.run(10, onThen: (v) => first = v);
      cont.run(20, onThen: (v) => second = v);

      expect(first, equals(15));
      expect(second, equals(25));
    });
  });

  group('Cont.thenDoWithEnv0', () {
    test('receives environment only', () {
      String? capturedEnv;
      int? result;

      Cont.of<String, Never, int>(99).thenDoWithEnv0((env) {
        capturedEnv = env;
        return Cont.of(0);
      }).run('myEnv', onThen: (v) => result = v);

      expect(capturedEnv, equals('myEnv'));
      expect(result, equals(0));
    });
  });
}
