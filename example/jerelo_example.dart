import 'package:jerelo/jerelo.dart';

import 'adt/decision.dart';
import 'adt/transaction.dart';
import 'adt/transaction_result.dart';
import 'mock_draft_service.dart';
import 'print_observer.dart';

void main() {
  /**
   * Transaction pipeline (domain flow)
   *
   * 1) Draft
   *    - Fetch transaction draft
   *    - Validate draft
   *      - if invalid -> error
   *
   * 2) Enrichment (concurrent)
   *    - In parallel:
   *        • resolve address from draft
   *        • resolve reputation from draft
   *    - Combine draft + address + reputation -> Transaction
   *
   * 3) Service selection
   *    - Derive TransactionService from Transaction
   *
   * 4) Decision gate
   *    - Ask for decision
   *      - rejected -> error (terminates)
   *      - approved -> produce TransactionResult
   *      - review   -> run review
   *          - if review rejects -> error
   *          - else -> produce TransactionResult
   *
   * 5) Reporting
   *    - Build report from TransactionResult (+ Transaction context)
   *
   * 6) Error reporting (catch-all)
   *    - Any error above -> generate error report instead
   */
  final program = getMockDraftService().flatMap((service) {
    return service
        .getTransactionDraft()
        .flatTap(service.validateTransactionDraft)
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
            isSequential: false,
          );
        })
        .flatMap(service.getTransactionService)
        .flatMap((transactionService) {
          return transactionService
              .getDecisionForTransaction()
              .flatMap<TransactionResult>((decision) {
                return switch (decision) {
                  Decision.rejected => Cont.raise(ContError("Rejected", StackTrace.current)),
                  Decision.approved => transactionService.getTransactionResult(),
                  Decision.review => transactionService.reviewForTransaction().flatMap0(transactionService.getTransactionResult),
                };
              })
              .flatMap(transactionService.getReportForTransactionAndResult);
        })
        .catchTerminate(service.getReportForErrors);
  });

  program.runWith(getObserver());
}
