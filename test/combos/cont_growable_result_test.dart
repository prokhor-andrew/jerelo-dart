import 'package:jerelo/jerelo.dart';
import 'package:test/test.dart';

void main() {
  final okPolicies = <String, OkPolicy<String>>{
    'sequence': OkPolicy.sequence(),
    'quitFast': OkPolicy.quitFast(),
    'runAll': OkPolicy.runAll((a, b) => '$a$b',
        shouldFavorCrash: false),
  };

  group('combinator results are growable lists', () {
    for (final entry in okPolicies.entries) {
      test('all with ${entry.key}', () {
        List<int>? values;
        Cont.all<(), String, int>(
          [Cont.of(1), Cont.of(2)],
          policy: entry.value,
        ).run((), onThen: (v) => values = v);

        values!.add(3);
        expect(values, equals([1, 2, 3]));
      });
    }

    final anyPolicies = <String, OkPolicy<int>>{
      'sequence': OkPolicy.sequence(),
      'quitFast': OkPolicy.quitFast(),
      'runAll': OkPolicy.runAll((a, b) => a + b,
          shouldFavorCrash: false),
    };
    for (final entry in anyPolicies.entries) {
      test('any with ${entry.key}', () {
        List<String>? errors;
        Cont.any<(), String, int>(
          [Cont.error('a'), Cont.error('b')],
          policy: entry.value,
        ).run((), onElse: (e) => errors = e);

        errors!.add('c');
        expect(errors, equals(['a', 'b', 'c']));
      });
    }
  });
}
