import 'dart:async';

import 'package:uuid/uuid.dart';

/// Lightweight runtime context for structured debug logging.
class StructuredLogContext {
  StructuredLogContext._();

  static const _flowIdZoneKey = #structuredFlowId;
  static const _uiActionZoneKey = #structuredUiAction;
  static const _uuid = Uuid();

  /// Correlation ID scoped to the current app launch.
  static final String sessionId = _uuid.v4();

  static String _currentRoute = '/';
  static String? _recentFlowId;
  static DateTime? _recentFlowUpdatedAt;
  static const _recentFlowRetention = Duration(minutes: 2);

  /// Current route path tracked by router instrumentation.
  static String get currentRoute => _currentRoute;

  /// Active flow ID from the current zone, if present.
  static String? get flowId {
    final zoneFlowId = Zone.current[_flowIdZoneKey];
    if (zoneFlowId is String && zoneFlowId.isNotEmpty) {
      return zoneFlowId;
    }
    return null;
  }

  /// Most recent completed/started flow ID retained for error correlation.
  static String? get recentFlowId {
    final id = _recentFlowId;
    final updatedAt = _recentFlowUpdatedAt;
    if (id == null || updatedAt == null) {
      return null;
    }
    if (DateTime.now().difference(updatedAt) > _recentFlowRetention) {
      _recentFlowId = null;
      _recentFlowUpdatedAt = null;
      return null;
    }
    return id;
  }

  /// UI action marker scoped to the current zone, if present.
  static String? get uiAction {
    final zoneUiAction = Zone.current[_uiActionZoneKey];
    if (zoneUiAction is String && zoneUiAction.isNotEmpty) {
      return zoneUiAction;
    }
    return null;
  }

  /// Updates the current route used in structured metadata.
  static void updateCurrentRoute(String route) {
    final normalized = route.trim();
    if (normalized.isNotEmpty) {
      _currentRoute = normalized;
    }
  }

  /// Creates a new unique flow ID.
  static String createFlowId() => _uuid.v4();

  /// Runs [action] inside a flow-aware zone.
  static Future<T> runFlow<T>({
    required Future<T> Function() action,
    String? flowId,
    String? uiAction,
  }) {
    final id = flowId ?? createFlowId();
    _recentFlowId = id;
    _recentFlowUpdatedAt = DateTime.now();

    return runZoned(
      action,
      zoneValues: {
        _flowIdZoneKey: id,
        if (uiAction != null && uiAction.isNotEmpty) _uiActionZoneKey: uiAction,
      },
    );
  }
}
