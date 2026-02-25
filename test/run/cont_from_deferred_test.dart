import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.fromDeferred', () {
    test('lazily creates inner Cont', () {
      bool created = false;
      int? value;

      final cont = Cont.fromDeferred<(), String, int>(() {
        created = true;
        return Cont.of(42);
      });

      expect(created, false);
      cont.run((), onThen: (val) => value = val);
      expect(created, true);
      expect(value, 42);
    });

    test('creates new inner Cont on each run', () {
      var callCount = 0;

      final cont = Cont.fromDeferred<(), String, int>(() {
        callCount++;
        return Cont.of(callCount);
      });

      int? value1;
      cont.run((), onThen: (val) => value1 = val);
      expect(value1, 1);
      expect(callCount, 1);

      int? value2;
      cont.run((), onThen: (val) => value2 = val);
      expect(value2, 2);
      expect(callCount, 2);
    });

    test('propagates error from inner Cont', () {
      String? error;

      final cont = Cont.fromDeferred<(), String, int>(() {
        return Cont.error('deferred err');
      });

      cont.run((), onElse: (e) => error = e);
      expect(error, 'deferred err');
    });

    test('crashes when thunk throws', () {
      ContCrash? crash;

      final cont = Cont.fromDeferred<(), String, int>(() {
        throw 'Thunk Error';
      });

      cont.run((), onCrash: (c) => crash = c);
      expect(crash, isA<NormalCrash>());
      expect((crash! as NormalCrash).error, 'Thunk Error');
    });
  });
}
