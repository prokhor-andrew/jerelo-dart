import 'package:jerelo/jerelo.dart';

extension ContCrashForeverExtension<E, F, A>
    on Cont<E, F, A> {
  /// Repeatedly retries the continuation on crash indefinitely.
  ///
  /// If the continuation crashes, retries it in an infinite loop that never
  /// stops on its own. The loop only terminates if the continuation succeeds
  /// or terminates with a business-logic error.
  ///
  /// This is the crash-channel counterpart to [elseForever]. While
  /// `elseForever` retries on termination indefinitely, `crashForever` retries
  /// on crash indefinitely.
  ///
  /// This is useful for:
  /// - Services that must always recover from unexpected crashes
  /// - Resilient operations that should never give up on transient failures
  /// - Self-healing systems that retry on any crash
  Cont<E, F, A> crashForever() {
    return crashUntil((_) {
      return false;
    });
  }
}
