// send http request

import 'package:jerelo/jerelo.dart';
import 'package:jerelo/src/cont_observer.dart';
import 'package:jerelo/src/cont_reporter.dart';

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
                //
                draft: draft,
                address: address,
                reputation: reputation,
              );
            },
          );
        })
        .flatMap((transaction) {
          return service
              .getDecisionForTransaction(transaction)
              .flatMap((decision) {
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

  // TODO: plug in consumers
  program.run(ContReporter.ignore(), ContObserver.ignore());
}

// TODO:
Cont<TransactionService> getTransactionService() {
  return Cont.raise("mock");
}

final class TransactionService {
  final Cont<TransactionDraft> Function() getTransactionDraft;

  final Cont<()> Function(TransactionDraft draft) validateTransactionDraft;

  final Cont<String> Function(TransactionDraft draft) getAddressFromTransactionDraft;

  final Cont<double> Function(TransactionDraft draft) getReputationFromTransactionDraft;

  final Cont<Transaction> Function({
    required TransactionDraft draft,
    required String address,
    required double reputation,
    //
  })
  getTransactionFromDraftAddressReputation;

  final Cont<Decision> Function(Transaction transaction) getDecisionForTransaction;

  final Cont<()> Function(Transaction transaction) reviewForTransaction;

  final Cont<TransactionResult> Function(Transaction transaction) getTransactionResult;

  final Cont<RiskReport> Function(Transaction transaction, TransactionResult result) getReportForTransactionAndResult;

  final Cont<RiskReport> Function(List<Object> errors) getReportForErrors;

  const TransactionService({
    required this.getTransactionDraft,
    required this.validateTransactionDraft,
    required this.getAddressFromTransactionDraft,
    required this.getReputationFromTransactionDraft,
    required this.getTransactionFromDraftAddressReputation,
    required this.getDecisionForTransaction,
    required this.reviewForTransaction,
    required this.getTransactionResult,
    required this.getReportForTransactionAndResult,
    required this.getReportForErrors,
    //
  });
}

final class TransactionDraft {
  final double amount;
  final String email;
  final String ip;

  const TransactionDraft({
    required this.amount,
    required this.email,
    required this.ip,
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

final class RiskReport {}

final class TransactionResult {}
