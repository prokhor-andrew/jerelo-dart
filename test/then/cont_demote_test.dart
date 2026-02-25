import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont.demote', () {
    test('terminates with computed error from value', () {
      String? error;

      Cont.of<(), String, int>(42)
          .demote((a) => 'demoted: $a')
          .run((), onElse: (e) => error = e);

      expect(error, 'demoted: 42');
    });

    test('does not call onThen', () {
      Cont.of<(), String, int>(42)
          .demote((a) => 'demoted')
          .run(
            (),
            onThen: (_) => fail('Should not be called'),
            onElse: (_) {},
          );
    });

    test('passes through original error', () {
      String? error;
      bool demoteCalled = false;

      Cont.error<(), String, int>('original')
          .demote((a) {
            demoteCalled = true;
            return 'demoted';
          })
          .run((), onElse: (e) => error = e);

      expect(demoteCalled, false);
      expect(error, 'original');
    });

    test('crashes when function throws', () {
      ContCrash? crash;

      Cont.of<(), String, int>(42)
          .demote((a) {
            throw 'Demote Error';
          })
          .run((), onCrash: (c) => crash = c);

      expect(crash, isA<NormalCrash>());
      expect((crash! as NormalCrash).error, 'Demote Error');
    });

    test('can be run multiple times', () {
      var callCount = 0;
      final cont = Cont.of<(), String, int>(42).demote((a) {
        callCount++;
        return 'demoted: $a';
      });

      String? error1;
      cont.run((), onElse: (e) => error1 = e);
      expect(error1, 'demoted: 42');
      expect(callCount, 1);

      String? error2;
      cont.run((), onElse: (e) => error2 = e);
      expect(error2, 'demoted: 42');
      expect(callCount, 2);
    });
  });

  group('Cont.demote0', () {
    test('terminates with error ignoring value', () {
      String? error;

      Cont.of<(), String, int>(42)
          .demote0(() => 'demoted')
          .run((), onElse: (e) => error = e);

      expect(error, 'demoted');
    });
  });

  group('Cont.demoteWith', () {
    test('terminates with constant error', () {
      String? error;

      Cont.of<(), String, int>(42)
          .demoteWith('constant error')
          .run((), onElse: (e) => error = e);

      expect(error, 'constant error');
    });
  });
}
