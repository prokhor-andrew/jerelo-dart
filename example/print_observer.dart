import 'package:jerelo/jerelo.dart';

import 'adt/risk_report.dart';

ContObserver<RiskReport> getObserver() {
  return ContObserver(
    (errors) {
      print("errors=$errors");
    },
    (report) {
      print("report=${_reportToString(report)}");
    },
    //
  );
}

String _reportToString(RiskReport report) {
  final buf = StringBuffer();

  buf.writeln("RiskReport");
  buf.writeln("- score: ${report.score.toStringAsFixed(2)}");
  buf.writeln("- summary: ${report.summary}");

  if (report.reasons.isEmpty) {
    buf.writeln("- reasons: (none)");
  } else {
    buf.writeln("- reasons:");
    for (final r in report.reasons) {
      buf.writeln("  - $r");
    }
  }

  return buf.toString();
}
