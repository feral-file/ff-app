import 'dart:io';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:drift/native.dart';

Future<void> main() async {
  // Open database
  final dbPath = '${Directory.current.path}/.dart_tool/app_database.sqlite';
  print('Checking database at: $dbPath');
  
  final db = AppDatabase(NativeDatabase.createInBackground(File(dbPath)));
  final service = DatabaseService(db);
  
  try {
    // Get all channels
    final channels = await service.getChannels();
    print('\n=== DATABASE CHECK ===');
    print('Total channels: ${channels.length}');
    
    if (channels.isEmpty) {
      print('No channels found in database');
    } else {
      print('\nChannels:');
      for (final channel in channels) {
        print('  - ${channel.name} (${channel.id}) - isPinned: ${channel.isPinned}');
      }
    }
    
    // Get all playlists
    final playlists = await service.getAllPlaylists();
    print('\nTotal playlists: ${playlists.length}');
    
    await db.close();
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}
