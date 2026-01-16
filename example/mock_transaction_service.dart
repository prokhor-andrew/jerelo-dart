import 'dart:math';

import 'package:jerelo/jerelo.dart';

import 'adt/decision.dart';
import 'adt/risk_report.dart';
import 'adt/transaction.dart';
import 'adt/transaction_result.dart';
import 'service/transaction_service.dart';

Cont<TransactionService> getMockTransactionService(Transaction transaction) {
  final rng = Random(1);

  bool chance(double p) => rng.nextDouble() < p;

  return Cont.of(
    TransactionService(
      getDecisionForTransaction: () {
        // 3%: fail to decide
        if (chance(0.03)) return Cont.raise(ContError(StateError("Decision engine crashed"), StackTrace.current));

        // 4%: none (engine unavailable / deferred)
        if (chance(0.04)) return Cont.empty();

        final decision = _randomDecision();

        return Cont.of(decision);
      },

      reviewForTransaction: () {
        // Only meaningful for medium risk, but allow anyway.
        if (chance(0.08)) return Cont.raise(ContError(StateError("Reviewer queue unavailable"), StackTrace.current));
        if (chance(0.05)) return Cont.empty();

        return Cont.of(());
      },

      getTransactionResult: () {
        // 5%: fail
        if (chance(0.05)) return Cont.raise(ContError(StateError("Payment provider error"), StackTrace.current));

        // 4%: none
        if (chance(0.04)) return Cont.empty();

        return Cont.of(TransactionResult.success(authCode: ""));
      },

      getReportForTransactionAndResult: (result) {
        // 4%: fail
        if (chance(0.04)) return Cont.raise(ContError(StateError("Report generator error"), StackTrace.current));

        // 3%: none
        if (chance(0.03)) return Cont.empty();

        final score = _scoreFrom(transaction: transaction, result: result);
        final reasons = <String>[
          if (transaction.address.contains("NG")) "Geo risk",
          if (transaction.draft.amount > 3000) "High amount",
          if (transaction.reputation < 0.3) "Low reputation",
          if (result.isDeclined) "Provider declined",
          if (result.isPending) "Pending review",
        ];

        return Cont.of(
          RiskReport(
            score: score,
            summary: score >= 0.7 ? "High risk" : (score >= 0.4 ? "Medium risk" : "Low risk"),
            reasons: reasons.isEmpty ? const ["No significant risk signals"] : reasons,
            //
          ),
        );
      },
      //
    ),
  );
}

double _scoreFrom({
  required Transaction transaction,
  required TransactionResult result,
  //
}) {
  var score = 0.0;
  score += (1.0 - transaction.reputation) * 0.7;
  if (transaction.address.contains("NG")) score += 0.3;
  if (transaction.draft.amount > 3000) score += 0.2;
  if (result.isDeclined) score += 0.2;
  if (result.isPending) score += 0.1;
  return score.clamp(0.0, 1.0);
}

Decision _randomDecision() {
  final roll = Random().nextInt(3); // 0..2
  return switch (roll) {
    0 => Decision.approved,
    1 => Decision.review,
    _ => Decision.rejected,
  };
}
