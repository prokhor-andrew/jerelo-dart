import 'package:jerelo/src/cont_error.dart';

sealed class RefCommit<S, V> {
  const RefCommit();

  static RefCommit<S, V> skip<S, V>([List<ContError> errors = const []]) {
    return _SkipCommit(errors);
  }

  static RefCommit<S, V> transit<S, V>(S state, V value) {
    return _TransitCommit(state, value);
  }

  static RefCommit<S, V> mutate<S, V>(S state) {
    return _MutateCommit(state);
  }

  R match<R>(R Function(List<ContError>) ifSkip, R Function(S state, V value) ifTransit, R Function(S state) ifMutate) {
    return switch (this) {
      _SkipCommit(errors: final errors) => ifSkip(errors),
      _TransitCommit(state: final state, value: final value) => ifTransit(state, value),
      _MutateCommit(state: final state) => ifMutate(state),
    };
  }

  void run(void Function(List<ContError> errors) ifSkip, void Function(S state, V value) ifTransit, void Function(S state) ifMutate) {
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
      (state) {
        return () {
          ifMutate(state);
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
      (_) {
        return false;
      },
    );
  }

  bool isTransit() {
    return match<bool>(
      (_) {
        return false;
      },
      (_, _) {
        return true;
      },
      (_) {
        return false;
      },
    );
  }

  bool isMutate() {
    return match<bool>(
      (_) {
        return false;
      },
      (_, _) {
        return false;
      },
      (_) {
        return true;
      },
    );
  }
}

final class _SkipCommit<S, V> extends RefCommit<S, V> {
  final List<ContError> errors;

  const _SkipCommit(this.errors);
}

final class _TransitCommit<S, V> extends RefCommit<S, V> {
  final S state;
  final V value;

  const _TransitCommit(this.state, this.value);
}

final class _MutateCommit<S, V> extends RefCommit<S, V> {
  final S state;

  const _MutateCommit(this.state);
}
