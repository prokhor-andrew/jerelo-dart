import 'dart:math';

import 'package:jerelo/jerelo.dart';

import 'jerelo_example.dart';
import 'transaction_service.dart';

Cont<TransactionService> getTransactionService() {
  final rng = Random(1);

  bool chance(double p) => rng.nextDouble() < p;

  return Cont.of(
    TransactionService(
      getTransactionDraft: () {
        // 5%: none (no draft available)
        if (chance(0.05)) return Cont.empty();

        // 8%: fail
        if (chance(0.08)) return Cont.raise(StateError("Draft service unavailable"));

        // otherwise success
        return Cont.of(
          TransactionDraft(
            id: "draft_${1000 + rng.nextInt(9000)}",
            amount: (10 + rng.nextInt(5000)).toDouble(),
            currency: "USD",
            ip: rng.nextBool() ? "203.0.113.10" : "198.51.100.44",
            email: rng.nextBool() ? "ok@example.com" : "fraud@example.com",
          ),
        );
      },

      validateTransactionDraft: (draft) {
        // Hard validation rules -> fail with explicit reason
        if (draft.amount <= 0) return Cont.raise(ArgumentError("Amount must be > 0"));
        if (draft.currency != "USD") return Cont.raise(ArgumentError("Unsupported currency: ${draft.currency}"));
        if (!draft.email.contains("@")) return Cont.raise(ArgumentError("Invalid email"));

        // Soft validation -> none (treat as “cannot validate now”)
        if (chance(0.03)) return Cont.empty();

        return Cont.of(());
      },

      getAddressFromTransactionDraft: (draft) {
        // 10%: none (no address)
        if (chance(0.10)) return Cont.empty();

        // 6%: fail
        if (chance(0.06)) return Cont.raise(StateError("Address lookup timeout"));

        final address = switch (draft.ip) {
          "203.0.113.10" => "Wichita, KS",
          "198.51.100.44" => "Lagos, NG",
          _ => "Unknown",
        };

        return Cont.of(address);
      },

      getReputationFromTransactionDraft: (draft) {
        // 7%: fail
        if (chance(0.07)) return Cont.raise(StateError("Reputation service error"));

        // 7%: none
        if (chance(0.07)) return Cont.empty();

        // Very rough scoring
        var rep = 0.6;
        if (draft.email.contains("fraud")) rep -= 0.5;
        if (draft.amount > 3000) rep -= 0.2;
        if (draft.ip == "198.51.100.44") rep -= 0.2;

        rep = rep.clamp(0.0, 1.0);
        return Cont.of(rep);
      },

      getTransactionFromDraftAddressReputation: ({required draft, required address, required reputation}) {
        // if we couldn't resolve meaningfully, return none
        if (address == "Unknown") return Cont.empty();

        return Cont.of(
          Transaction(
            draft: draft,
            address: address,
            reputation: reputation,
            //
          ),
        );
      },

      getDecisionForTransaction: (transaction) {
        // 3%: fail to decide
        if (chance(0.03)) return Cont.raise(StateError("Decision engine crashed"));

        // 4%: none (engine unavailable / deferred)
        if (chance(0.04)) return Cont.empty();

        final decision = _randomDecision();

        return Cont.of(decision);
      },

      reviewForTransaction: (transaction) {
        // Only meaningful for medium risk, but allow anyway.
        if (chance(0.08)) return Cont.raise(StateError("Reviewer queue unavailable"));
        if (chance(0.05)) return Cont.empty();

        return Cont.of(());
      },

      getTransactionResult: (transaction) {
        // 5%: fail
        if (chance(0.05)) return Cont.raise(StateError("Payment provider error"));

        // 4%: none
        if (chance(0.04)) return Cont.empty();

        return Cont.of(TransactionResult.success(authCode: ""));
      },

      getReportForTransactionAndResult: (transaction, result) {
        // 4%: fail
        if (chance(0.04)) return Cont.raise(StateError("Report generator error"));

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

      getReportForErrors: (errors) {
        // Always succeeds (fallback report), but could also be none/fail if you want.
        return Cont.of(
          RiskReport(
            score: 1.0,
            summary: "System error",
            reasons: errors.map((e) => e.toString()).toList(growable: false),
            //
          ),
          //
        );
      },
    ),
  );
}

Decision _randomDecision() {
  final roll = Random().nextInt(3); // 0..2
  return switch (roll) {
    0 => Decision.approved,
    1 => Decision.review,
    _ => Decision.rejected,
  };
}

double _scoreFrom({required Transaction transaction, required TransactionResult result}) {
  var score = 0.0;
  score += (1.0 - transaction.reputation) * 0.7;
  if (transaction.address.contains("NG")) score += 0.3;
  if (transaction.draft.amount > 3000) score += 0.2;
  if (result.isDeclined) score += 0.2;
  if (result.isPending) score += 0.1;
  return score.clamp(0.0, 1.0);
}
