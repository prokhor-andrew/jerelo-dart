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
