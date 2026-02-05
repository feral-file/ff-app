import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

/// Observer that reports provider lifecycle and failures to app logging.
final class AppProviderObserver extends ProviderObserver {
  /// Creates a Riverpod observer that logs provider lifecycle changes.
  AppProviderObserver({Logger? logger})
    : _logger = logger ?? Logger('Riverpod');

  final Logger _logger;

  @override
  void didAddProvider(
    ProviderObserverContext context,
    Object? value,
  ) {
    _logger.fine('add ${_providerName(context)} = ${_short(value)}');
  }

  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    if (identical(previousValue, newValue)) {
      return;
    }

    _logger.fine(
      'update ${_providerName(context)} '
      '${_short(previousValue)} -> ${_short(newValue)}',
    );
  }

  @override
  void didDisposeProvider(ProviderObserverContext context) {
    _logger.fine('dispose ${_providerName(context)}');
  }

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

  String _short(Object? value) {
    if (value == null) {
      return 'null';
    }

    final text = value.toString().replaceAll('\n', ' ');
    if (text.length <= 220) {
      return text;
    }
    return '${text.substring(0, 217)}...';
  }
}
