part of '../cont.dart';

/// Decision type returned by [_stackSafeLoop]'s `keepRunningIf` callback.
///
/// Determines whether the loop should continue iterating or stop and produce
/// a final result.
sealed class _StackSafeLoopPolicy<A, B> {
  const _StackSafeLoopPolicy();
}

/// Signals that the loop should continue with the provided value fed into
/// the next iteration's computation.
final class _StackSafeLoopPolicyKeepRunning<A, B>
    extends _StackSafeLoopPolicy<A, B> {
  final A value;

  const _StackSafeLoopPolicyKeepRunning(this.value);
}

/// Signals that the loop should stop and deliver the provided value to the
/// escape callback.
final class _StackSafeLoopPolicyStop<A, B>
    extends _StackSafeLoopPolicy<A, B> {
  final B value;

  const _StackSafeLoopPolicyStop(this.value);
}

/// Runs a stack-safe loop that supports both synchronous and asynchronous
/// iterations.
///
/// The loop processes a [seed] value through repeated iterations. Each
/// iteration first checks [keepRunningIf] to decide whether to continue
/// or stop. If continuing, [computation] is called with the current value
/// and a callback to supply the next seed. When the loop stops,
/// [escape] receives the final result.
///
/// Stack safety is achieved by detecting whether [computation] completes
/// synchronously (via the callback being invoked before returning). When
/// synchronous, the loop continues via a `while` loop instead of recursion.
/// When asynchronous, it recurses on callback invocation.
void _stackSafeLoop<A, B, C>({
  required A seed,
  required _StackSafeLoopPolicy<B, C> Function(A)
      keepRunningIf,
  required void Function(B, void Function(A)) computation,
  required void Function(C) escape,
  //
}) {
  var mutableSeedCopy = seed;

  while (true) {
    final policy = keepRunningIf(mutableSeedCopy);

    switch (policy) {
      case _StackSafeLoopPolicyStop<B, C>(
          value: final value,
        ):
        escape(value);
        return;
      case _StackSafeLoopPolicyKeepRunning<B, C>():
        break;
    }

    bool isSchedulerUsed = false;
    bool isSync1 = true;
    bool isSync2 = false;

    computation(policy.value, (updatedA) {
      if (isSchedulerUsed) {
        return;
      }

      isSchedulerUsed = true;

      if (isSync1) {
        isSync2 = true;
        mutableSeedCopy = updatedA;
        return;
      }
      // not sync

      _stackSafeLoop(
        seed: updatedA,
        keepRunningIf: keepRunningIf,
        computation: computation,
        escape: escape,
        //
      );
    });
    isSync1 = false;
    if (isSync2) {
      continue;
    } else {
      break;
    }
  }
}
