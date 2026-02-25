import 'package:app/domain/models/channel.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:logging/logging.dart';

/// Service for bootstrapping the application data.
/// Creates initial channels and structures.
class BootstrapService {
  /// Creates a BootstrapService.
  BootstrapService({
    required DatabaseService databaseService,
  }) : _databaseService = databaseService {
    _log = Logger('BootstrapService');
  }

  final DatabaseService _databaseService;
  late final Logger _log;

  /// Bootstrap the application.
  /// This creates the "My Collection" virtual channel if it doesn't exist.
  Future<void> bootstrap() async {
    try {
      _log.info('Starting bootstrap');

      await _createMyCollectionChannel();

      _log.info('Bootstrap completed');
    } catch (e, stack) {
      _log.severe('Bootstrap failed', e, stack);
      rethrow;
    }
  }

  /// Create "My Collection" virtual channel.
  Future<void> _createMyCollectionChannel() async {
    final existingChannel = await _databaseService.getChannelById(
      'my_collection',
    );

    if (existingChannel != null) {
      _log.info('My Collection channel already exists');
      return;
    }

    final myCollection = Channel(
      id: 'my_collection',
      name: 'My Collection',
      type: ChannelType.localVirtual,
      description: 'Your personal collection of artworks',
      isPinned: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      sortOrder: 0, // First in the list
    );

    await _databaseService.ingestChannel(myCollection);
    _log.info('Created My Collection channel');
  }
}
