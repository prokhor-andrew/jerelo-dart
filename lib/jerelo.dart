/// A continuation monad library for Dart.
///
/// Provides [Cont], a powerful abstraction for composing asynchronous and
/// effectful computations using continuation-passing style. Supports
/// environment injection, error handling, and parallel and sequential
/// composition.
library;

export 'src/cont.dart';
export 'src/api/combos/and.dart';
export 'src/api/combos/or.dart';
export 'src/api/combos/coalesce.dart';
export 'src/api/combos/ok_policy.dart';
export 'src/api/combos/crash_policy.dart';
export 'src/api/then/do.dart';
export 'src/api/decorate/decorate.dart';
export 'src/api/then/map.dart';
export 'src/api/else/do.dart';
export 'src/api/else/map.dart';
export 'src/api/crash/do.dart';
export 'src/api/env/env.dart';
export 'src/api/extensions/never.dart';
export 'src/api/extensions/flatten.dart';
export 'src/api/crash/do_variants.dart';
export 'src/api/crash/forever.dart';
export 'src/api/crash/fork.dart';
export 'src/api/crash/recover.dart';
export 'src/api/crash/tap.dart';
export 'src/api/crash/unless.dart';
export 'src/api/crash/until.dart';
export 'src/api/crash/while.dart';
export 'src/api/crash/zip.dart';
export 'src/api/else/do_variants.dart';
export 'src/api/else/forever.dart';
export 'src/api/else/fork.dart';
export 'src/api/else/map_variants.dart';
export 'src/api/else/promote.dart';
export 'src/api/else/tap.dart';
export 'src/api/else/unless.dart';
export 'src/api/else/until.dart';
export 'src/api/else/while.dart';
export 'src/api/else/zip.dart';
export 'src/api/env/local_variants.dart';
export 'src/api/then/demote.dart';
export 'src/api/then/do_variants.dart';
export 'src/api/then/forever.dart';
export 'src/api/then/fork.dart';
export 'src/api/then/if.dart';
export 'src/api/then/map_variants.dart';
export 'src/api/then/tap.dart';
export 'src/api/then/until.dart';
export 'src/api/then/while.dart';
export 'src/api/then/zip.dart';
