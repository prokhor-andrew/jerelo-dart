// part of '../cont.dart';
//
// Cont<E, F, List<A>> _allSequence<E, F, A>(
//   List<Cont<E, F, A>> list,
// ) {
//   list = list.toList(); // defensive copy
//   return Cont.fromRun((runtime, observer) {
//     list = list.toList(); // defensive copy again
//     _seq<ContFail<F>, A>(
//       total: list.length,
//       onRun: (
//         index,
//         updateCancel,
//         updatePrimary,
//         updateSecondary,
//       ) {
//         final Cont<E, F, A> cont = _absurdify(list[index]);
//         cont._run(
//           runtime,
//           ContObserver._(
//             (error) {
//               if (runtime.isCancelled()) {
//                 updateCancel();
//                 return;
//               }
//               updateSecondary(error);
//             },
//             (a) {
//               if (runtime.isCancelled()) {
//                 updateCancel();
//                 return;
//               }
//               updatePrimary(a);
//             },
//           ),
//         );
//       },
//       onPrimary: observer.onThen,
//       onSecondary: observer.onElse,
//       onError: (error) {
//         observer.onElse(
//           ContCrash.withStackTrace(
//             error.error,
//             error.stackTrace,
//           ),
//         );
//       },
//     );
//   });
// }
//
// Cont<E, List<F>, A> _anySequence<E, F, A>(
//   List<Cont<E, F, A>> list,
// ) {
//   list = list.toList(); // defensive copy
//   return Cont.fromRun((runtime, observer) {
//     list = list.toList(); // defensive copy again
//     _seq<A, F>(
//       total: list.length,
//       onRun: (
//         index,
//         updateCancel,
//         updatePrimary,
//         updateSecondary,
//       ) {
//         final Cont<E, F, A> cont = _absurdify(list[index]);
//         cont._run(
//           runtime,
//           ContObserver._(
//             (error) {
//               if (runtime.isCancelled()) {
//                 updateCancel();
//                 return;
//               }
//               updatePrimary(error);
//             },
//             (a) {
//               if (runtime.isCancelled()) {
//                 updateCancel();
//                 return;
//               }
//               updateSecondary(a);
//             },
//           ),
//         );
//       },
//       onPrimary: (error) {
//         observer.onElse(ContError(error));
//       },
//       onSecondary: observer.onThen,
//       onError: (error) {
//         observer.onElse(
//           ContCrash.withStackTrace(
//             error.error,
//             error.stackTrace,
//           ),
//         );
//       },
//     );
//   });
// }
//
// void _seq<F, A>({
//   required int total,
//   required void Function(
//     int index,
//     void Function() updateCancel,
//     void Function(A) updatePrimary,
//     void Function(F) updateSecondary,
//   ) onRun,
//   required void Function(List<A> values) onPrimary,
//   required void Function(F f) onSecondary,
//   required void Function(ContCrash error) onError,
// }) {
//   _stackSafeLoop<
//       _Triple<List<A>, F, ContCrash>?, // state
//       List<A>, // loop input
//       _Triple<List<A>, F, ContCrash>? // loop output
//       >(
//     seed: _Value1([]),
//     keepRunningIf: (state) {
//       switch (state) {
//         case null:
//           return _StackSafeLoopPolicyStop(null);
//         case _Value1(a: final values):
//           if (values.length >= total) {
//             return _StackSafeLoopPolicyStop(
//               _Value1(values),
//             );
//           }
//           return _StackSafeLoopPolicyKeepRunning(values);
//         case _Value2(b: final f):
//           return _StackSafeLoopPolicyStop(_Value2(f));
//         case _Value3(c: final error):
//           return _StackSafeLoopPolicyStop(_Value3(error));
//       }
//     },
//     computation: (values, update) {
//       final i = values.length;
//       try {
//         onRun(
//           i,
//           () {
//             update(null);
//           },
//           (a) {
//             update(
//               _Value1([...values, a]),
//             ); // defensive copy
//           },
//           (f) {
//             update(_Value2(f));
//           },
//         );
//       } catch (error, st) {
//         update(
//           _Value3(ContCrash.withStackTrace(error, st)),
//         );
//       }
//     },
//     escape: (triple) {
//       switch (triple) {
//         case null:
//           // cancellation
//           return;
//         case _Value1(a: final values):
//           onPrimary(values);
//         case _Value2(b: final f):
//           onSecondary(f);
//         case _Value3(c: final error):
//           onError(error);
//       }
//     },
//   );
// }
