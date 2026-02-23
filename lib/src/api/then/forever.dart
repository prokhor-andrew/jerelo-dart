import 'package:jerelo/jerelo.dart';

extension ContThenForeverExtension<E, F, A>
    on Cont<E, F, A> {
  /// Repeatedly executes the continuation indefinitely.
  ///
  /// Runs the continuation in an infinite loop that never stops on its own.
  /// The loop only terminates if the underlying continuation terminates on the
  /// else (error) channel.
  ///
  /// The return type `Cont<E, F, Never>` indicates that this continuation never
  /// produces a value — it either runs forever or terminates with a
  /// business-logic error.
  ///
  /// This is useful for:
  /// - Daemon-like processes that run continuously
  /// - Server loops that handle requests indefinitely
  /// - Event loops that continuously process events
  /// - Background tasks that should never stop
  ///
  /// Example:
  /// ```dart
  /// // A server that handles requests forever
  /// final server = acceptConnection()
  ///     .thenDo((conn) => handleConnection(conn))
  ///     .thenForever();
  ///
  /// server.run(env, onElse: (error) => print('Server stopped: $error'));
  /// ```
  Cont<E, F, Never> thenForever() {
    return thenUntil((_) {
      return false;
    }).thenMap((value) {
      return value as Never;
    });
  }
}
