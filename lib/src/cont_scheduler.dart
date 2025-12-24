final class ContScheduler {
  final void Function() Function(void Function() action) schedule;

  const ContScheduler._(this.schedule);

  void run(void Function() action) {
    schedule(action)();
  }

  static ContScheduler custom(void Function() Function(void Function() action) schedule) {
    return ContScheduler._(schedule);
  }

  static ContScheduler delayed([Duration duration = Duration.zero]) {
    return ContScheduler._((action) {
      return () {
        Future.delayed(duration, action);
      };
    });
  }

  static ContScheduler microTask() {
    return ContScheduler._((action) {
      return () {
        Future.microtask(action);
      };
    });
  }

  static ContScheduler immediate() {
    return ContScheduler._((action) {
      return action;
    });
  }
}
