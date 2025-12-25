sealed class RefCommit<S, V> {
  const RefCommit();

  static RefCommit<S, V> transit<S, V>(S state, V value) {
    return _TransitCommit(state, value);
  }

  static RefCommit<S, V> mutate<S, V>(S state) {
    return _MutateCommit(state);
  }

  R match<R>(R Function(S state, V value) ifTransit, R Function(S state) ifMutate) {
    return switch (this) {
      _TransitCommit(state: final state, value: final value) => ifTransit(state, value),
      _MutateCommit(state: final state) => ifMutate(state),
    };
  }

  void run(void Function(S state, V value) ifTransit, void Function(S state) ifMutate) {
    match<void Function()>(
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

  bool isTransit() {
    return match<bool>(
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
      (_, _) {
        return false;
      },
      (_) {
        return true;
      },
    );
  }
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
