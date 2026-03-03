import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Fake PathProviderPlatform for testing.
class FakePathProviderPlatform extends PathProviderPlatform {
  /// Creates a FakePathProviderPlatform.
  FakePathProviderPlatform(this.tempPath);

  /// The path to use for all directory requests.
  final String tempPath;

  @override
  Future<String?> getTemporaryPath() async => tempPath;

  @override
  Future<String?> getApplicationSupportPath() async => tempPath;

  @override
  Future<String?> getLibraryPath() async => tempPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => tempPath;

  @override
  Future<String?> getApplicationCachePath() async => tempPath;

  @override
  Future<String?> getExternalStoragePath() async => tempPath;

  @override
  Future<List<String>?> getExternalCachePaths() async => [tempPath];

  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async => [tempPath];

  @override
  Future<String?> getDownloadsPath() async => tempPath;
}
