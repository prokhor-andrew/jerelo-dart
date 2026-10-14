import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

// Never-typed continuations passed where a wider type is expected.
// Each test goes through a different kind of operator that used to
// call absurdify() on its input.
final Cont<(), Never, int> neverFails = Cont.of(1);
final Cont<(), String, Never> neverSucceeds =
    Cont.error('oops');

void main() {
  group('Cont.fromDeferred with Never-typed input', () {
    test('fromDeferred', () {
      int? result;

      Cont.fromDeferred<(), String, int>(() => neverFails)
          .run((), onThen: (v) => result = v);

      expect(result, equals(1));
    });
  });
}
