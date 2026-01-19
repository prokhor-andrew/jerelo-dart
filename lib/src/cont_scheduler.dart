final class ContScheduler {
  final void Function(void Function() action) schedule;

  const ContScheduler._(this.schedule);

  static ContScheduler fromSchedule(void Function(void Function() action) schedule) {
    return ContScheduler._(schedule);
  }

  static void _exec(void Function() action) {
    action();
  }

  static const ContScheduler immediate = ContScheduler._(_exec);

  static ContScheduler delayed([Duration duration = Duration.zero]) {
    return ContScheduler.fromSchedule((action) {
      Future.delayed(duration, action);
    });
  }

  static ContScheduler microtask() {
    return ContScheduler.fromSchedule((action) {
      Future.microtask(action);
    });
  }
}

final class TestContScheduler {
  final List<void Function()> _q = [];

  ContScheduler asScheduler() {
    return ContScheduler.fromSchedule((a) {
      _q.add(a);
    });
  }

  int pendingCount() {
    return _q.length;
  }

  bool isIdle() {
    return _q.isEmpty;
  }

  /// Runs queued actions FIFO. Protects against actions that enqueue more.
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
