/// A continuation monad library for Dart.
///
/// Provides [Cont], a powerful abstraction for composing asynchronous and
/// effectful computations using continuation-passing style. Supports
/// environment injection, error handling, parallel and sequential composition,
/// resource management, and cooperative cancellation.
library;

export 'src/cont.dart';
export 'src/api/cont_error.dart';
export 'src/api/combos/cont_policy.dart';
