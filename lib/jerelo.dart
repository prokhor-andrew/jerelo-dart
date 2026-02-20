/// A continuation monad library for Dart.
///
/// Provides [Cont], a powerful abstraction for composing asynchronous and
/// effectful computations using continuation-passing style. Supports
/// environment injection, error handling, parallel and sequential composition,
/// resource management, and cooperative cancellation.
library;

export 'src/cont.dart';
export 'src/api/combos/and.dart';
export 'src/api/combos/or.dart';
export 'src/api/combos/cont_policy.dart';
export 'src/api/then/do.dart';
export 'src/api/then/tap.dart';
export 'src/api/then/zip.dart';
export 'src/api/then/if.dart';
export 'src/api/then/until.dart';
export 'src/api/decorate/decorate.dart';
export 'src/api/then/map.dart';
export 'src/api/else/do.dart';
export 'src/api/else/map.dart';
export 'src/api/else/tap.dart';
export 'src/api/else/unless.dart';
export 'src/api/else/zip.dart';
export 'src/api/env/env.dart';
export 'src/api/extensions/never.dart';
