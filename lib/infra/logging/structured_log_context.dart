import 'dart:async';

import 'package:uuid/uuid.dart';

/// Lightweight runtime context for structured debug logging.
class StructuredLogContext {
  StructuredLogContext._();

  static const _flowIdZoneKey = #structuredFlowId;
  static const _uiActionZoneKey = #structuredUiAction;
  static const _uuid = Uuid();

  static final String sessionId = _uuid.v4();

  static String _currentRoute = '/';
  static String? _recentFlowId;

  static String get currentRoute => _currentRoute;

  static String? get flowId {
    final zoneFlowId = Zone.current[_flowIdZoneKey];
    if (zoneFlowId is String && zoneFlowId.isNotEmpty) {
      return zoneFlowId;
    }
    return _recentFlowId;
  }

  static String? get uiAction {
    final zoneUiAction = Zone.current[_uiActionZoneKey];
    if (zoneUiAction is String && zoneUiAction.isNotEmpty) {
      return zoneUiAction;
    }
    return null;
  }

  static void updateCurrentRoute(String route) {
    final normalized = route.trim();
    if (normalized.isNotEmpty) {
      _currentRoute = normalized;
    }
  }

  static String createFlowId() => _uuid.v4();

  static Future<T> runFlow<T>({
    required Future<T> Function() action,
    String? flowId,
    String? uiAction,
  }) {
    final id = flowId ?? createFlowId();
    _recentFlowId = id;

    return runZoned(
      action,
      zoneValues: {
        _flowIdZoneKey: id,
        if (uiAction != null && uiAction.isNotEmpty) _uiActionZoneKey: uiAction,
      },
    );
  }
}
