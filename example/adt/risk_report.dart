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
