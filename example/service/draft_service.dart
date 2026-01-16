import 'package:jerelo/jerelo.dart';


import '../adt/draft.dart';
import '../adt/risk_report.dart';
import '../adt/transaction.dart';
import 'transaction_service.dart';

final class DraftService {
  final Cont<Draft> Function() getTransactionDraft;

  final Cont<()> Function(Draft draft) validateTransactionDraft;

  final Cont<String> Function(Draft draft) getAddressFromTransactionDraft;

  final Cont<double> Function(Draft draft) getReputationFromTransactionDraft;

  final Cont<Transaction> Function({
    required Draft draft,
    required String address,
    required double reputation,
    //
  })
  getTransactionFromDraftAddressReputation;

  final Cont<TransactionService> Function(Transaction transaction) getTransactionService;

  final Cont<RiskReport> Function(List<Object> errors) getReportForErrors;

  const DraftService({
    required this.getTransactionDraft,
    required this.validateTransactionDraft,
    required this.getAddressFromTransactionDraft,
    required this.getReputationFromTransactionDraft,
    required this.getTransactionFromDraftAddressReputation,
    required this.getTransactionService,
    required this.getReportForErrors,
    //
  });
}
