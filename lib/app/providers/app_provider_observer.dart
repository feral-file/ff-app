import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

/// Observer that reports provider failures to app logging.
final class AppProviderObserver extends ProviderObserver {
  /// Creates a Riverpod observer that logs provider failures.
  AppProviderObserver({Logger? logger})
    : _logger = logger ?? Logger('Riverpod');

  final Logger _logger;

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    _logger.severe(
      'fail ${_providerName(context)}',
      error,
      stackTrace,
    );
  }

  String _providerName(ProviderObserverContext context) {
    final provider = context.provider;
    return provider.name ?? provider.runtimeType.toString();
  }
}
