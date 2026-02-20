// part of '../cont.dart';
//
// void _whenAllPar<P, S>({
//   required int total,
//   required void Function(
//     int index,
//     void Function(P) onPrimary,
//     void Function(S) onSecondary,
//   ) onRun,
//   required S Function(S acc, S next) combine,
//   required void Function(List<P> primaries) onAllPrimary,
//   required void Function(S secondary) onAnySecondary,
// }) {
//   if (total == 0) {
//     onAllPrimary([]);
//     return;
//   }
//
//   S? seed;
//   final List<P> results = [];
//   var i = 0;
//
//   void handlePrimary(P p) {
//     i += 1;
//     final seedCopy = seed;
//     if (seedCopy != null && i >= total) {
//       onAnySecondary(seedCopy);
//       return;
//     }
//     results.add(p);
//     if (i >= total) {
//       onAllPrimary(results);
//     }
//   }
//
//   void handleSecondary(S s) {
//     i += 1;
//     final seedCopy = seed;
//     if (seedCopy == null) {
//       if (i >= total) {
//         onAnySecondary(s);
//         return;
//       }
//       seed = s;
//     } else {
//       final newSeed = combine(seedCopy, s);
//       if (i >= total) {
//         onAnySecondary(newSeed);
//         return;
//       }
//       seed = newSeed;
//     }
//   }
//
//   for (var index = 0; index < total; index++) {
//     onRun(index, handlePrimary, handleSecondary);
//   }
// }
//
// Cont<E, F, List<A>> _whenAllAll<E, F, A>(
//   List<Cont<E, F, A>> list,
//   F Function(F acc, F error) combine,
// ) {
//   list = list.toList();
//   return Cont.fromRun((runtime, observer) {
//     list = list.toList();
//     _whenAllPar<A, F>(
//       total: list.length,
//       onRun: (index, onPrimary, onSecondary) {
//         final cont = list[index];
//         try {
//           cont._run(
//             runtime,
//             ContObserver._(
//               (error) {
//                 if (runtime.isCancelled()) {
//                   return;
//                 }
//                 onSecondary(error);
//               },
//               (a) {
//                 if (runtime.isCancelled()) {
//                   return;
//                 }
//                 onPrimary(a);
//               },
//             ),
//           );
//         } catch (panic, st) {
//           onSecondary(
//             ContCrash.withStackTrace(panic, st),
//           );
//         }
//       },
//       combine: combine,
//       onAllPrimary: observer.onThen,
//       onAnySecondary: observer.onElse,
//     );
//   });
// }
//
// Cont<E, List<F>, A> _whenAllAny<E, F, A>(
//   List<Cont<E, F, A>> list,
//   A Function(A acc, A value) combine,
// ) {
//   list = list.toList();
//   return Cont.fromRun((runtime, observer) {
//     list = list.toList();
//     _whenAllPar<F, A>(
//       total: list.length,
//       onRun: (index, onPrimary, onSecondary) {
//         final cont = list[index];
//         try {
//           cont._run(
//             runtime,
//             ContObserver._(
//               (error) {
//                 if (runtime.isCancelled()) {
//                   return;
//                 }
//                 onPrimary(error);
//               },
//               (a) {
//                 if (runtime.isCancelled()) {
//                   return;
//                 }
//                 onSecondary(a);
//               },
//             ),
//           );
//         } catch (panic, st) {
//           onPrimary(ContCrash.withStackTrace(panic, st));
//         }
//       },
//       combine: combine,
//       onAllPrimary: (errors) {
//         return observer.onElse(
//           ContError(errors),
//         );
//       },
//       onAnySecondary: observer.onThen,
//     );
//   });
// }
