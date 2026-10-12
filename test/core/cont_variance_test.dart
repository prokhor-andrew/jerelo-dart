import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  group('Cont variance', () {
    test('operators run on a value upcast to a wider type', () {
      final Cont<(), Object?> wide = Cont.of<(), int>(1);
      Object? result;
      List<ContError>? errors;

      wide.thenMap((v) => '$v!').run(
        (),
        onElse: (e) => errors = e,
        onThen: (v) => result = v,
      );

      expect(errors, isNull);
      expect(result, equals('1!'));
    });

    test('either with untyped quitFast policy runs', () {
      final Cont<(), int> left = Cont.of(1);
      final Cont<(), int> right = Cont.of(2);
      Object? result;
      List<ContError>? errors;

      Cont.either(
        left,
        right,
        policy: ContEitherPolicy.quitFast(),
      ).run(
        (),
        onElse: (e) => errors = e,
        onThen: (v) => result = v,
      );

      expect(errors, isNull);
      expect(result, equals(1));
    });

    test('all runs a list upcast to a wider type', () {
      final List<Cont<(), Object?>> list = [
        Cont.of<(), int>(1),
        Cont.of<(), String>('two'),
      ];
      Object? result;
      List<ContError>? errors;

      Cont.all(
        list,
        policy: ContBothPolicy.quitFast(),
      ).run(
        (),
        onElse: (e) => errors = e,
        onThen: (v) => result = v,
      );

      expect(errors, isNull);
      expect(result, equals([1, 'two']));
    });

    test('operators run on a Never-typed value upcast', () {
      final Cont<(), Never> never = Cont.stop<(), Never>();
      final Cont<(), int> upcast = never;
      int? result;
      List<ContError>? errors;

      upcast.thenMap((v) => v + 1).run(
        (),
        onElse: (e) => errors = e,
        onThen: (v) => result = v,
      );

      expect(result, isNull);
      expect(errors, isEmpty);
    });

    test('explicitly typed policy still works', () {
      final Cont<(), int> left = Cont.of(1);
      final Cont<(), int> right = Cont.of(2);
      int? result;

      Cont.either(
        left,
        right,
        policy: ContEitherPolicy.quitFast<int>(),
      ).run((), onThen: (v) => result = v);

      expect(result, equals(1));
    });
  });
}
