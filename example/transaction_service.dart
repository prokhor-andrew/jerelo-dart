import 'package:jerelo/jerelo.dart';

import 'jerelo_example.dart';

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
