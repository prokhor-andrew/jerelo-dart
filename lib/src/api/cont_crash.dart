part of '../cont.dart';

sealed class ContCrash {
  const ContCrash();

  static NormalCrash? tryCatch(void Function() function) {
    try {
      function();
      return null;
    } catch (error, st) {
      return NormalCrash._(error, st);
    }
  }
}

final class NormalCrash extends ContCrash {
  final Object error;

  final StackTrace stackTrace;

  const NormalCrash._(this.error, this.stackTrace);

  @override
  String toString() {
    return "NormalCrash { error=$error, stackTrace=$stackTrace }";
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    if (other is! NormalCrash) {
      return false;
    }

    return error == other.error;
  }

  @override
  int get hashCode => error.hashCode;
}

final class MergedCrash extends ContCrash {
  final ContCrash left;
  final ContCrash right;

  const MergedCrash._(this.left, this.right);

  @override
  String toString() {
    return "MergedCrash { left=$left, right=$right }";
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    if (other is! MergedCrash) {
      return false;
    }

    return left == other.left && right == other.right;
  }

  @override
  int get hashCode => left.hashCode ^ right.hashCode;
}

final class ListedCrash extends ContCrash {
  final List<ContCrash> crashes;

  const ListedCrash._(this.crashes);

  @override
  String toString() {
    return "ListedCrash { crashes=$crashes }";
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    if (other is! ListedCrash) {
      return false;
    }

    return crashes == other.crashes;
  }

  @override
  int get hashCode => crashes.hashCode;
}
