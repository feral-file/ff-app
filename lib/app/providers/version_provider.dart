import 'package:app/app/routing/app_navigator_key.dart';
import 'package:app/infra/api/pubdoc_api.dart';
import 'package:app/infra/services/version_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for [PubDocApi] (release notes + version compatibility).
final pubDocApiProvider = Provider<PubDocApi>((ref) {
  return PubDocApiImpl();
});

/// Provider for [VersionService].
final versionServiceProvider = Provider<VersionService>(
  (ref) {
    final pubDocApi = ref.watch(pubDocApiProvider);
    return VersionService(
      pubDocApi: pubDocApi,
      navigatorKey: appNavigatorKey,
    );
  },
);
