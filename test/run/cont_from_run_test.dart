import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.fromRun', () {
    test('produces value via onThen', () {
      int? result;
      Cont.fromRun<(), String, int>((runtime, observer) {
        observer.onThen(42);
      }).run((), onThen: (v) => result = v);
      expect(result, equals(42));
    });

    test('produces error via onElse', () {
      String? result;
      Cont.fromRun<(), String, int>((runtime, observer) {
        observer.onElse('oops');
      }).run((), onElse: (e) => result = e);
      expect(result, equals('oops'));
    });

    test('catches thrown exceptions as crashes', () {
      ContCrash? crash;
      Cont.fromRun<(), String, int>((runtime, observer) {
        throw Exception('boom');
      }).run(
        (),
        onCrash: (c) => crash = c,
        onPanic: (_) {},
      );
      expect(crash, isA<NormalCrash>());
    });

    test('provides environment via runtime', () {
      int? captured;
      Cont.fromRun<int, String, int>((runtime, observer) {
        captured = runtime.env();
        observer.onThen(runtime.env());
      }).run(99);
      expect(captured, equals(99));
    });

    test('ignores duplicate onThen calls', () {
      int callCount = 0;
      Cont.fromRun<(), String, int>((runtime, observer) {
        observer.onThen(1);
        observer.onThen(2);
      }).run((), onThen: (_) => callCount++);
      expect(callCount, equals(1));
    });

    test('ignores callbacks after first onElse', () {
      int thenCount = 0;
      int elseCount = 0;
      Cont.fromRun<(), String, int>((runtime, observer) {
        observer.onElse('first');
        observer.onElse('second');
        observer.onThen(42);
      }).run(
        (),
        onThen: (_) => thenCount++,
        onElse: (_) => elseCount++,
      );
      expect(thenCount, equals(0));
      expect(elseCount, equals(1));
    });

    test('can be run multiple times', () {
      final cont = Cont.fromRun<(), String, int>(
          (runtime, observer) {
        observer.onThen(42);
      });

      int? first;
      int? second;
      cont.run((), onThen: (v) => first = v);
      cont.run((), onThen: (v) => second = v);

      expect(first, equals(42));
      expect(second, equals(42));
    });

    test('supports cancellation', () async {
      bool secondStepRan = false;

      final cont = Cont.fromRun<(), String, int>(
          (runtime, observer) {
        Future.microtask(() => observer.onThen(42));
      }).thenDo((_) => Cont.fromRun<(), String, int>(
              (runtime, observer) {
            secondStepRan = true;
            observer.onThen(84);
          }));

      final token = cont.run(());
      token.cancel();

      await Future.delayed(Duration.zero);

      expect(secondStepRan, isFalse);
    });
  });
}
