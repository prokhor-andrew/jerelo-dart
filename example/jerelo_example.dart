// send http request

import 'package:jerelo/jerelo.dart';

import 'mock_transaction_service.dart';
import 'print_reporter_observer.dart';

void main() {
  /**
   * - get transaction draft
   * - validate transaction draft -> throws error if invalid
   * - get address for transaction draft
   * - concurrently ( get address for draft, and get reputation for draft )
   * - get transaction for draft, reputation and address
   * - get decision for transaction -> throws error if decision reject
   *    - for decision review -> review transaction -> throws  error if rejected
   * - for decision approved -> get transaction result
   * - get report for transaction result and transaction
   * - catch any errors above and generate report
   */
  final program = getTransactionService().flatMap((service) {
    return service
        .getTransactionDraft()
        .flatMap((draft) {
          return service.validateTransactionDraft(draft).mapTo(draft);
        })
        .flatMap((draft) {
          return Cont.both(
            //
            service.getAddressFromTransactionDraft(draft),
            service.getReputationFromTransactionDraft(draft),
            (address, reputation) {
              return Transaction(
                draft: draft,
                address: address,
                reputation: reputation,
                //
              );
            },
          );
        })
        .flatMap((transaction) {
          return service
              .getDecisionForTransaction(transaction)
              .flatMap<TransactionResult>((decision) {
                return switch (decision) {
                  Decision.rejected => Cont.raise("Rejected"),
                  Decision.approved => service.getTransactionResult(transaction),
                  Decision.review => service.reviewForTransaction(transaction).flatMap0(() {
                    return service.getTransactionResult(transaction);
                  }),
                };
              })
              .flatMap((result) {
                return service.getReportForTransactionAndResult(transaction, result);
              });
        })
        .catchTerminate(service.getReportForErrors);
  });

  program.run(getReporter(), getObserver());
}

final class TransactionDraft {
  final String id;
  final double amount;
  final String currency;
  final String ip;
  final String email;

  const TransactionDraft({
    required this.id,
    required this.amount,
    required this.currency,
    required this.ip,
    required this.email,
    //
  });
}

final class Transaction {
  final TransactionDraft draft;
  final String address;
  final double reputation;

  const Transaction({
    required this.draft,
    required this.address,
    required this.reputation,
    //
  });
}

enum Decision { rejected, approved, review }

final class RiskReport {
  final double score; // 0..1
  final String summary;
  final List<String> reasons;

  const RiskReport({
    required this.score,
    required this.summary,
    required this.reasons,
    //
  });
}

sealed class TransactionResult {
  const TransactionResult();

  bool get isSuccess => this is _Success;

  bool get isPending => this is _Pending;

  bool get isDeclined => this is _Declined;

  factory TransactionResult.success({required String authCode}) => _Success(authCode);

  factory TransactionResult.pending({required String reason}) => _Pending(reason);

  factory TransactionResult.declined({required String reason}) => _Declined(reason);
}

final class _Success extends TransactionResult {
  final String authCode;

  const _Success(this.authCode);
}

final class _Pending extends TransactionResult {
  final String reason;

  const _Pending(this.reason);
}

final class _Declined extends TransactionResult {
  final String reason;

  const _Declined(this.reason);
}
