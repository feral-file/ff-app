import 'package:app/domain/models/ff1_error.dart';
import 'package:app/infra/logging/structured_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

/// Observer that reports provider failures to app logging.
final class AppProviderObserver extends ProviderObserver {
  /// Creates a Riverpod observer that logs provider failures.
  AppProviderObserver({Logger? logger})
    : _structuredLogger = AppStructuredLog.forLogger(
        logger ?? Logger('Riverpod'),
      );

  final StructuredLogger _structuredLogger;

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    // User/caller cancellation is expected; do not treat as a provider failure.
    if (error is FF1ConnectionCancelledError) {
      return;
    }
    final providerName = _providerName(context);
    _structuredLogger.error(
      event: 'provider_failed',
      message: 'provider failed $providerName',
      error: error,
      stackTrace: stackTrace,
      payload: {
        'provider': providerName,
      },
    );
  }

  String _providerName(ProviderObserverContext context) {
    final provider = context.provider;
    return provider.name ?? provider.runtimeType.toString();
  }
}
