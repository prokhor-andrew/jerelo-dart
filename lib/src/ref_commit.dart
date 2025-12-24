import 'package:jerelo/src/cont_error.dart';

final class RefCommit<S, V> {
  final (S, V)? _value;
  final List<ContError> _errors;

  const RefCommit._(this._value, this._errors);

  static RefCommit<S, V> skip<S, V>([List<ContError> errors = const []]) {
    return RefCommit._(null, errors);
  }

  static RefCommit<S, V> transit<S, V>(S state, V value) {
    return RefCommit._((state, value), []);
  }

  R match<R>(R Function(List<ContError>) ifSkip, R Function(S state, V value) ifTransit) {
    final value = _value;
    if (value == null) {
      return ifSkip(_errors);
    } else {
      return ifTransit(value.$1, value.$2);
    }
  }

  void run(void Function(List<ContError> errors) ifSkip, void Function(S state, V value) ifTransit) {
    match<void Function()>(
      (errors) {
        return () {
          ifSkip(errors);
        };
      },
      (state, value) {
        return () {
          ifTransit(state, value);
        };
      },
    )();
  }

  bool isSkip() {
    return match<bool>(
      (_) {
        return true;
      },
      (_, _) {
        return false;
      },
    );
  }

  bool isTransit() {
    return !isSkip();
  }
}
