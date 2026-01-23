/// Controls when and how continuation actions are executed.
///
/// [ContScheduler] provides different execution strategies for continuations,
/// allowing control over synchronous vs asynchronous execution and timing.
final class ContScheduler {
  /// The scheduling function that determines how actions are executed.
  final void Function(void Function() action) schedule;

  const ContScheduler._(this.schedule);

  /// Creates a scheduler from a custom schedule function.
  ///
  /// - [schedule]: A function that takes an action and schedules its execution.
  static ContScheduler fromSchedule(void Function(void Function() action) schedule) {
    return ContScheduler._(schedule);
  }

  static void _exec(void Function() action) {
    action();
  }

  /// Immediate scheduler that executes actions synchronously.
  ///
  /// Actions are executed immediately without any delay or queuing.
  static const ContScheduler immediate = ContScheduler._(_exec);

  /// Creates a scheduler that delays execution by the specified duration.
  ///
  /// Schedules actions to run after the specified duration using `Future.delayed`.
  ///
  /// - [duration]: The delay before execution. Defaults to [Duration.zero].
  static ContScheduler delayed([Duration duration = Duration.zero]) {
    return ContScheduler.fromSchedule((action) {
      Future.delayed(duration, action);
    });
  }

  /// Creates a scheduler that executes actions on the microtask queue.
  ///
  /// Schedules actions using `Future.microtask`, which runs after the current
  /// synchronous code completes but before the next event loop iteration.
  static ContScheduler microtask() {
    return ContScheduler.fromSchedule((action) {
      Future.microtask(action);
    });
  }
}

/// A test scheduler that queues actions for manual, controlled execution.
///
/// Useful for testing continuation behavior by allowing precise control
/// over when scheduled actions are executed.
final class TestContScheduler {
  final List<void Function()> _q = [];

  /// Converts this test scheduler to a regular [ContScheduler].
  ///
  /// Returns a scheduler that enqueues actions in this test scheduler's queue
  /// instead of executing them immediately.
  ContScheduler asScheduler() {
    return ContScheduler.fromSchedule((a) {
      _q.add(a);
    });
  }

  /// Returns the number of actions waiting in the queue.
  int pendingCount() {
    return _q.length;
  }

  /// Checks if the scheduler has no pending actions.
  ///
  /// Returns `true` if the queue is empty, `false` otherwise.
  bool isIdle() {
    return _q.isEmpty;
  }

  /// Executes queued actions in FIFO order.
  ///
  /// Runs queued actions one by one. Protected against infinite loops from
  /// self-enqueuing actions by using a step counter.
  ///
  /// - [maxSteps]: Maximum number of actions to execute. Use `-1` for unlimited.
  void flush([int maxSteps = -1]) {
    var steps = 0;
    while (_q.isNotEmpty) {
      if (maxSteps > -1 && steps >= maxSteps) {
        break;
      }
      steps += 1;
      final a = _q.removeAt(0);
      a();
    }
  }
}
