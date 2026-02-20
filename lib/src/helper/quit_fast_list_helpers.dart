// part of '../cont.dart';
//
// void _quitFastPar<E, QF, C>({
//   required ContRuntime<E> runtime,
//   required int total,
//   required void Function(
//     int index,
//     ContRuntime<E> sharedRuntime,
//     void Function(QF) onQuitFast,
//     void Function(C) onCollect,
//   ) onRun,
//   required void Function(QF value) onFirstQuitFast,
//   required void Function(List<C> collected) onAllCollected,
// }) {
//   if (total == 0) {
//     onAllCollected([]);
//     return;
//   }
//
//   bool isDone = false;
//   final collectedResults = List<C?>.filled(total, null);
//   int amountOfCollected = 0;
//
//   final ContRuntime<E> sharedRuntime = ContRuntime._(
//     runtime.env(),
//     () {
//       return runtime.isCancelled() || isDone;
//     },
//     runtime.onPanic,
//   );
//
//   void handleQuitFast(QF value) {
//     if (isDone) {
//       return;
//     }
//     isDone = true;
//     onFirstQuitFast(value);
//   }
//
//   for (int i = 0; i < total; i++) {
//     onRun(
//       i,
//       sharedRuntime,
//       (qf) {
//         if (sharedRuntime.isCancelled()) {
//           return;
//         }
//         handleQuitFast(qf);
//       },
//       (c) {
//         if (sharedRuntime.isCancelled()) {
//           return;
//         }
//
//         collectedResults[i] = c;
//         amountOfCollected += 1;
//         if (amountOfCollected < total) {
//           return;
//         }
//         onAllCollected(collectedResults.cast<C>());
//       },
//     );
//   }
// }
//
// Cont<E, F, List<A>> _quitFastAll<E, F, A>(
//   List<Cont<E, F, A>> list,
// ) {
//   list = list.toList();
//   return Cont.fromRun((runtime, observer) {
//     list = list.toList();
//     _quitFastPar<E, ContFail<F>, A>(
//       runtime: runtime,
//       total: list.length,
//       onRun: (i, shared, onQuitFast, onCollect) {
//         try {
//           list[i]._run(
//             shared,
//             ContObserver._(
//               onQuitFast,
//               onCollect,
//             ),
//           );
//         } catch (error, st) {
//           onQuitFast(ContCrash.withStackTrace(error, st));
//         }
//       },
//       onFirstQuitFast: observer.onElse,
//       onAllCollected: observer.onThen,
//     );
//   });
// }
//
// Cont<E, List<F>, A> _quitFastAny<E, F, A>(
//   List<Cont<E, F, A>> list,
// ) {
//   list = list.toList();
//   return Cont.fromRun((runtime, observer) {
//     list = list.toList();
//     _quitFastPar<E, A, F>(
//       runtime: runtime,
//       total: list.length,
//       onRun: (i, shared, onQuitFast, onCollect) {
//         try {
//           list[i]._run(
//             shared,
//             ContObserver._(
//               onCollect,
//               onQuitFast,
//             ),
//           );
//         } catch (error, st) {
//           onCollect(ContCrash.withStackTrace(error, st));
//         }
//       },
//       onFirstQuitFast: observer.onThen,
//       onAllCollected: (errors) {
//         observer.onElse(ContError(errors));
//       },
//     );
//   });
// }
