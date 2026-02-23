import 'package:jerelo/jerelo.dart';

extension ContElseForeverExtension<E, F, A>
    on Cont<E, F, A> {
  /// Repeatedly retries the continuation on termination indefinitely.
  ///
  /// If the continuation terminates, retries it in an infinite loop that never
  /// stops on its own. The loop only terminates if the continuation succeeds.
  ///
  /// This is the error-channel counterpart to [thenForever]. While
  /// `thenForever` loops the success path indefinitely, `elseForever` retries
  /// on termination indefinitely.
  ///
  /// This is useful for:
  /// - Services that must always promote past errors
  /// - Resilient connections that automatically reconnect
  /// - Operations that should never give up on transient failures
  /// - Self-healing systems that retry on any error
  ///
  /// Example:
  /// ```dart
  /// // A connection that automatically reconnects forever
  /// final connection = connectToServer()
  ///     .elseForever();
  ///
  /// // A resilient worker that never stops retrying
  /// final worker = processJob()
  ///     .elseTap((errors) => logError(errors))
  ///     .elseForever();
  /// ```
  Cont<E, Never, A> elseForever() {
    return elseUntil((_) {
      return false;
    }).elseMap((value) {
      return value as Never;
    });
  }
}
