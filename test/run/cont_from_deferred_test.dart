import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.fromDeferred', () {
    test('lazily creates inner Cont', () {
      int thunkCallCount = 0;

      final cont = Cont.fromDeferred<(), String, int>(() {
        thunkCallCount++;
        return Cont.of(42);
      });

      expect(thunkCallCount, equals(0));
      cont.run(());
      expect(thunkCallCount, equals(1));
    });

    test('creates new inner Cont on each run', () {
      int thunkCallCount = 0;

      final cont = Cont.fromDeferred<(), String, int>(() {
        thunkCallCount++;
        return Cont.of(thunkCallCount);
      });

      int? first;
      int? second;
      cont.run((), onThen: (v) => first = v);
      cont.run((), onThen: (v) => second = v);

      expect(thunkCallCount, equals(2));
      expect(first, equals(1));
      expect(second, equals(2));
    });

    test('propagates error from inner Cont', () {
      String? error;

      Cont.fromDeferred<(), String, int>(() {
        return Cont.error('inner error');
      }).run((), onElse: (e) => error = e);

      expect(error, equals('inner error'));
    });

    test('crashes when thunk throws', () {
      ContCrash? crash;

      Cont.fromDeferred<(), String, int>(() {
        throw Exception('thunk boom');
      }).run(
        (),
        onCrash: (c) => crash = c,
        onPanic: (_) {},
      );

      expect(crash, isA<NormalCrash>());
    });
  });
}
