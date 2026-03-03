import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Represents the state of a mutation (async operation).
sealed class MutationState<T> {
  const MutationState();
}

/// Mutation has not been called yet or has been reset.
class MutationIdle<T> extends MutationState<T> {
  const MutationIdle();
}

/// Mutation is currently executing.
class MutationPending<T> extends MutationState<T> {
  const MutationPending();
}

/// Mutation completed successfully with a result.
class MutationSuccess<T> extends MutationState<T> {
  const MutationSuccess(this.value);

  /// The successful result value.
  final T value;
}

/// Mutation failed with an error.
class MutationError<T> extends MutationState<T> {
  const MutationError(this.error, [this.stackTrace]);

  /// The error that occurred.
  final Object error;

  /// Optional stack trace.
  final StackTrace? stackTrace;
}

/// Notifier for managing mutation state.
/// Use this to track async operations with loading/error/success states.
class MutationNotifier<T> extends Notifier<MutationState<T>> {
  @override
  MutationState<T> build() {
    return const MutationIdle();
  }

  /// Execute an async operation and track its state.
  /// Returns the result if successful, throws if failed.
  Future<T> run(Future<T> Function() operation) async {
    try {
      state = const MutationPending();
      final result = await operation();
      if (!ref.mounted) return result;
      state = MutationSuccess(result);
      return result;
    } catch (error, stackTrace) {
      if (!ref.mounted) rethrow;
      state = MutationError(error, stackTrace);
      rethrow;
    }
  }

  /// Reset the mutation to idle state.
  void reset() {
    state = const MutationIdle();
  }
}

/// Helper extension for pattern matching on MutationState.
extension MutationStateExtension<T> on MutationState<T> {
  /// Check if the mutation is idle.
  bool get isIdle => this is MutationIdle<T>;

  /// Check if the mutation is pending.
  bool get isPending => this is MutationPending<T>;

  /// Check if the mutation succeeded.
  bool get isSuccess => this is MutationSuccess<T>;

  /// Check if the mutation failed.
  bool get isError => this is MutationError<T>;

  /// Get the success value, or null if not successful.
  T? get valueOrNull {
    final self = this;
    if (self is MutationSuccess<T>) {
      return self.value;
    }
    return null;
  }

  /// Get the error, or null if no error.
  Object? get errorOrNull {
    final self = this;
    if (self is MutationError<T>) {
      return self.error;
    }
    return null;
  }

  /// Execute different callbacks based on the state.
  R when<R>({
    required R Function() idle,
    required R Function() pending,
    required R Function(T value) success,
    required R Function(Object error, StackTrace? stackTrace) error,
  }) {
    final self = this;
    if (self is MutationIdle<T>) {
      return idle();
    } else if (self is MutationPending<T>) {
      return pending();
    } else if (self is MutationSuccess<T>) {
      return success(self.value);
    } else if (self is MutationError<T>) {
      return error(self.error, self.stackTrace);
    }
    throw StateError('Unknown mutation state: $this');
  }

  /// Execute callbacks based on the state, with optional cases.
  R maybeWhen<R>({
    required R Function() orElse,
    R Function()? idle,
    R Function()? pending,
    R Function(T value)? success,
    R Function(Object error, StackTrace? stackTrace)? error,
  }) {
    final self = this;
    if (self is MutationIdle<T> && idle != null) {
      return idle();
    } else if (self is MutationPending<T> && pending != null) {
      return pending();
    } else if (self is MutationSuccess<T> && success != null) {
      return success(self.value);
    } else if (self is MutationError<T> && error != null) {
      return error(self.error, self.stackTrace);
    }
    return orElse();
  }
}
