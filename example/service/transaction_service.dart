import 'package:jerelo/jerelo.dart';

import '../adt/decision.dart';
import '../adt/risk_report.dart';
import '../adt/transaction_result.dart';


final class TransactionService {
  final Cont<Decision> Function() getDecisionForTransaction;

  final Cont<()> Function() reviewForTransaction;

  final Cont<TransactionResult> Function() getTransactionResult;

  final Cont<RiskReport> Function(TransactionResult result) getReportForTransactionAndResult;

  const TransactionService({
    required this.getDecisionForTransaction,
    required this.reviewForTransaction,
    required this.getTransactionResult,
    required this.getReportForTransactionAndResult,
    //
  });
}
