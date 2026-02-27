import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.of', () {
    test('Cont.of is run correctly', () {
      int? result;
      Cont.of<(), String, int>(42).run(
        (),
        onThen: (v) => result = v,
      );
      expect(result, equals(42));
    });

    test('Cont.of does not call onElse', () {
      bool elseCalled = false;
      Cont.of<(), String, int>(42).run(
        (),
        onElse: (_) => elseCalled = true,
      );
      expect(elseCalled, isFalse);
    });

    test('Cont.of does not call onCrash', () {
      bool crashCalled = false;
      Cont.of<(), String, int>(42).run(
        (),
        onCrash: (_) => crashCalled = true,
      );
      expect(crashCalled, isFalse);
    });

    test('Cont.of does not call onPanic', () {
      bool panicCalled = false;
      Cont.of<(), String, int>(42).run(
        (),
        onPanic: (_) => panicCalled = true,
      );
      expect(panicCalled, isFalse);
    });

    test('Cont.of can be run multiple times', () {
      final cont = Cont.of<(), String, int>(42);

      int? first;
      int? second;
      cont.run((), onThen: (v) => first = v);
      cont.run((), onThen: (v) => second = v);

      expect(first, equals(42));
      expect(second, equals(42));
    });
  });
}
