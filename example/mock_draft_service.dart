import 'dart:math';

import 'package:jerelo/jerelo.dart';

import 'adt/draft.dart';
import 'adt/risk_report.dart';
import 'adt/transaction.dart';
import 'mock_transaction_service.dart';
import 'service/draft_service.dart';

Cont<DraftService> getMockDraftService() {
  final rng = Random(1);

  bool chance(double p) => rng.nextDouble() < p;

  return Cont.of(
    DraftService(
      getTransactionDraft: () {
        // 5%: none (no draft available)
        if (chance(0.05)) return Cont.terminate();

        // 8%: fail
        if (chance(0.08)) return Cont.terminate([ContError(StateError("Draft service unavailable"), StackTrace.current)]);

        // otherwise success
        return Cont.of(
          Draft(amount: (10 + rng.nextInt(5000)).toDouble(), currency: "USD", ip: rng.nextBool() ? "203.0.113.10" : "198.51.100.44", email: rng.nextBool() ? "ok@example.com" : "fraud@example.com"),
        );
      },

      validateTransactionDraft: (draft) {
        // Hard validation rules -> fail with explicit reason
        if (draft.amount <= 0) return Cont.terminate([ContError(ArgumentError("Amount must be > 0"), StackTrace.current)]);
        if (draft.currency != "USD") return Cont.terminate([ContError(ArgumentError("Unsupported currency: ${draft.currency}"), StackTrace.current)]);
        if (!draft.email.contains("@")) return Cont.terminate([ContError(ArgumentError("Invalid email"), StackTrace.current)]);

        // Soft validation -> none (treat as “cannot validate now”)
        if (chance(0.03)) return Cont.terminate();

        return Cont.of(());
      },

      getAddressFromTransactionDraft: (draft) {
        // 10%: none (no address)
        if (chance(0.10)) return Cont.terminate();

        // 6%: fail
        if (chance(0.06)) return Cont.terminate([ContError(StateError("Address lookup timeout"), StackTrace.current)]);

        final address = switch (draft.ip) {
          "203.0.113.10" => "Wichita, KS",
          "198.51.100.44" => "Lagos, NG",
          _ => "Unknown",
        };

        return Cont.of(address);
      },

      getReputationFromTransactionDraft: (draft) {
        // 7%: fail
        if (chance(0.07)) return Cont.terminate([ContError(StateError("Reputation service error"), StackTrace.current)]);

        // 7%: none
        if (chance(0.07)) return Cont.terminate();

        // Very rough scoring
        var rep = 0.6;
        if (draft.email.contains("fraud")) rep -= 0.5;
        if (draft.amount > 3000) rep -= 0.2;
        if (draft.ip == "198.51.100.44") rep -= 0.2;

        rep = rep.clamp(0.0, 1.0);
        return Cont.of(rep);
      },

      getTransactionFromDraftAddressReputation:
          ({
            required draft,
            required address,
            required reputation,
            //
          }) {
            // if we couldn't resolve meaningfully, return none
            if (address == "Unknown") return Cont.terminate();

            return Cont.of(
              Transaction(
                draft: draft,
                address: address,
                reputation: reputation,
                //
              ),
            );
          },

      getTransactionService: getMockTransactionService,

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
