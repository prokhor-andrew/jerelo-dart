import 'package:jerelo/jerelo.dart';

/// Extension providing conditional branching operations for [Cont] values.
///
/// This extension enables fluent if-then-else style branching for continuations,
/// allowing conditional execution paths based on the result of a computation.
extension ContBranchExtension<A> on Cont<A> {
  /// Starts a conditional branch based on a boolean continuation computed from the value.
  ///
  /// Creates a builder that allows chaining `then` and `other` operations to form
  /// a complete conditional expression. The condition function receives the continuation's
  /// value and returns a boolean continuation that determines which branch to take.
  ///
  /// - [f]: Function that computes a boolean continuation from the value.
  ContThenBuilder<A> when(Cont<bool> Function(A) f) {
    return ContThenBuilder._(this, f);
  }

  /// Starts a conditional branch based on a boolean continuation independent of the value.
  ///
  /// Similar to [when] but the condition function does not receive the continuation's
  /// value. Useful when the condition is computed independently.
  ///
  /// - [f]: Zero-argument function that computes a boolean continuation.
  ContThenBuilder<A> when0(Cont<bool> Function() f) {
    return when((_) {
      return f();
    });
  }

  /// Starts a conditional branch using a pre-computed boolean continuation.
  ///
  /// A convenience method that uses an existing boolean continuation as the condition,
  /// without needing to wrap it in a function.
  ///
  /// - [cont]: Boolean continuation to use as the condition.
  ContThenBuilder<A> whenTo(Cont<bool> cont) {
    return when0(() {
      return cont;
    });
  }
}

/// Builder for specifying the "then" branch of a conditional continuation.
///
/// This class is part of the fluent API for conditional branching. It holds the
/// original continuation and condition, waiting for the "then" operation to be
/// specified before moving to the "else" branch.
final class ContThenBuilder<A> {
  final Cont<A> _cont;
  final Cont<bool> Function(A) _if;

  const ContThenBuilder._(this._cont, this._if);

  /// Specifies the "then" branch to execute when the condition is true.
  ///
  /// Defines the continuation to execute when the condition evaluates to true.
  /// The function receives the original value and returns a continuation of a
  /// potentially different type.
  ///
  /// - [f]: Function that computes the continuation for the true branch.
  ContElseBuilder<A, A2> then<A2>(Cont<A2> Function(A) f) {
    return ContElseBuilder._(_cont, _if, f);
  }

  /// Specifies the "then" branch independent of the original value.
  ///
  /// Similar to [then] but the continuation function does not receive the
  /// original value. Useful when the true branch doesn't need the input value.
  ///
  /// - [f]: Zero-argument function that computes the continuation for the true branch.
  ContElseBuilder<A, A2> then0<A2>(Cont<A2> Function() f) {
    return then((_) {
      return f();
    });
  }

  /// Specifies a pre-computed continuation for the "then" branch.
  ///
  /// A convenience method that uses an existing continuation as the true branch,
  /// without needing to wrap it in a function.
  ///
  /// - [cont]: Continuation to execute when the condition is true.
  ContElseBuilder<A, A2> thenTo<A2>(Cont<A2> cont) {
    return then0(() {
      return cont;
    });
  }
}

/// Builder for completing a conditional continuation with the "else" branch.
///
/// This class holds the original continuation, condition, and "then" branch,
/// waiting for the "other" (else) operation to be specified to complete the
/// conditional expression and produce the final continuation.
final class ContElseBuilder<A, A2> {
  final Cont<A> _cont;
  final Cont<bool> Function(A) _if;
  final Cont<A2> Function(A) _then;

  const ContElseBuilder._(this._cont, this._if, this._then);

  /// Completes the conditional by specifying the "else" branch.
  ///
  /// Defines the continuation to execute when the condition evaluates to false.
  /// This produces the final continuation that represents the complete if-then-else
  /// expression. When executed, it will evaluate the condition and run either the
  /// "then" or "else" branch accordingly.
  ///
  /// - [f]: Function that computes the continuation for the false branch.
  Cont<A2> other(Cont<A2> Function(A) f) {
    return _cont.flatMap((a) {
      return _if(a).flatMap((condition) {
        return condition ? _then(a) : f(a);
      });
    });
  }

  /// Completes the conditional with an "else" branch independent of the original value.
  ///
  /// Similar to [other] but the continuation function does not receive the
  /// original value. Useful when the false branch doesn't need the input value.
  ///
  /// - [f]: Zero-argument function that computes the continuation for the false branch.
  Cont<A2> other0(Cont<A2> Function() f) {
    return other((_) {
      return f();
    });
  }

  /// Completes the conditional with a pre-computed continuation for the "else" branch.
  ///
  /// A convenience method that uses an existing continuation as the false branch,
  /// without needing to wrap it in a function.
  ///
  /// - [cont]: Continuation to execute when the condition is false.
  Cont<A2> otherTo(Cont<A2> cont) {
    return other0(() {
      return cont;
    });
  }
}
