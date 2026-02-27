import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.askThen', () {
    test('Cont.askThen triggers onThen with same value',
        () {
      int? result;
      Cont.askThen<int, String>().run(
        42,
        onThen: (v) => result = v,
      );
      expect(result, equals(42));
    });

    test('Cont.askThen triggers onThen with same null', () {
      int? result;
      bool called = false;
      Cont.askThen<int?, String>().run(
        null,
        onThen: (v) {
          called = true;
          result = v;
        },
      );
      expect(called, isTrue);
      expect(result, isNull);
    });

    test('Cont.askThen preserves environment identity', () {
      final env = Object();
      Object? captured;
      Cont.askThen<Object, Never>().run(
        env,
        onThen: (v) => captured = v,
      );
      expect(identical(captured, env), isTrue);
    });

    test('Cont.askThen does not trigger onElse', () {
      bool elseCalled = false;
      Cont.askThen<int, String>().run(
        42,
        onElse: (_) => elseCalled = true,
      );
      expect(elseCalled, isFalse);
    });

    test('Cont.askThen does not trigger onPanic', () {
      bool panicCalled = false;
      Cont.askThen<int, String>().run(
        42,
        onPanic: (_) => panicCalled = true,
      );
      expect(panicCalled, isFalse);
    });

    test('Cont.askThen can be run multiple times', () {
      final cont = Cont.askThen<int, String>();

      int? first;
      int? second;
      cont.run(1, onThen: (v) => first = v);
      cont.run(2, onThen: (v) => second = v);

      expect(first, equals(1));
      expect(second, equals(2));
    });
  });

  group('Cont.askElse', () {
    test('Cont.askElse triggers onElse with environment',
        () {
      int? result;
      Cont.askElse<int, Never>().run(
        42,
        onElse: (e) => result = e,
      );
      expect(result, equals(42));
    });

    test('Cont.askElse does not trigger onThen', () {
      bool thenCalled = false;
      Cont.askElse<int, Never>().run(
        42,
        onThen: (_) => thenCalled = true,
      );
      expect(thenCalled, isFalse);
    });
  });
}
