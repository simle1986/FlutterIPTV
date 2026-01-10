import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'dart:io' show Directory;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../services/web_api_service.dart';

class DatabaseHelper {
  static Database? _database;
  static WebApiService? _webApi; // For Web API communication
  static const String _databaseName = 'flutter_iptv.db';
  static const int _databaseVersion = 3; // Upgraded for sources column

  Future<void> initialize() async {
    if (_database != null || (kIsWeb && _webApi != null)) return;

    debugPrint('DatabaseHelper: Starting initialization...');
    debugPrint('DatabaseHelper: kIsWeb = $kIsWeb');

    if (kIsWeb) {
      // For Web, use API service instead of local database
      debugPrint('DatabaseHelper: Initializing Web API service...');
      try {
        _webApi = WebApiService();
        
        // Test connection to backend
        final isHealthy = await _webApi!.healthCheck();
        if (isHealthy) {
          debugPrint('DatabaseHelper: Web API service initialized successfully');
        } else {
          debugPrint('DatabaseHelper: Warning - Backend server may not be running');
        }
        return;
      } catch (e) {
        debugPrint('DatabaseHelper: Web API service initialization failed: $e');
        rethrow;
      }
    }

    debugPrint('DatabaseHelper: databaseFactory = ${databaseFactory.runtimeType}');

    // Note: FFI initialization is handled in main.dart

    final Directory appDir = await getApplicationDocumentsDirectory();
    final String path = join(appDir.path, _databaseName);
    debugPrint('DatabaseHelper: Desktop path = $path');

    try {
      debugPrint('DatabaseHelper: Attempting to open database...');
      
      _database = await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
      
      debugPrint('Database initialized successfully: $path');
    } catch (e) {
      debugPrint('Database initialization failed: $e');
      rethrow;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // Playlists table
    await db.execute('''
      CREATE TABLE playlists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        url TEXT,
        file_path TEXT,
        is_active INTEGER DEFAULT 1,
        last_updated INTEGER,
        channel_count INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');

    // Channels table
    await db.execute('''
      CREATE TABLE channels (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        playlist_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        url TEXT NOT NULL,
        sources TEXT,
        logo_url TEXT,
        group_name TEXT,
        epg_id TEXT,
        is_active INTEGER DEFAULT 1,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE
      )
    ''');

    // Favorites table
    await db.execute('''
      CREATE TABLE favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        channel_id INTEGER NOT NULL,
        position INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (channel_id) REFERENCES channels(id) ON DELETE CASCADE
      )
    ''');

    // Watch history table
    await db.execute('''
      CREATE TABLE watch_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        channel_id INTEGER NOT NULL,
        watched_at INTEGER NOT NULL,
        duration_seconds INTEGER DEFAULT 0,
        FOREIGN KEY (channel_id) REFERENCES channels(id) ON DELETE CASCADE
      )
    ''');

    // EPG data table
    await db.execute('''
      CREATE TABLE epg_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        channel_epg_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        start_time INTEGER NOT NULL,
        end_time INTEGER NOT NULL,
        category TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_channels_playlist ON channels(playlist_id)');
    await db.execute('CREATE INDEX idx_channels_group ON channels(group_name)');
    await db.execute('CREATE INDEX idx_favorites_channel ON favorites(channel_id)');
    await db.execute('CREATE INDEX idx_history_channel ON watch_history(channel_id)');
    await db.execute('CREATE INDEX idx_epg_channel ON epg_data(channel_epg_id)');
    await db.execute('CREATE INDEX idx_epg_time ON epg_data(start_time, end_time)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add channel_count column to playlists table
      try {
        await db.execute('ALTER TABLE playlists ADD COLUMN channel_count INTEGER DEFAULT 0');
      } catch (e) {
        // Ignore if column already exists
        debugPrint('Migration error (ignored): $e');
      }
    }
    if (oldVersion < 3) {
      // Add sources column to channels table for multi-source support
      try {
        await db.execute('ALTER TABLE channels ADD COLUMN sources TEXT');
      } catch (e) {
        // Ignore if column already exists
        debugPrint('Migration error (ignored): $e');
      }
    }
  }

  Database get db {
    if (kIsWeb) {
      throw StateError('Database not available on Web. Use Web API methods.');
    }
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }
    return _database!;
  }

  WebApiService get webApi {
    if (!kIsWeb) {
      throw StateError('Web API only available on Web platform.');
    }
    if (_webApi == null) {
      throw StateError('Web API not initialized. Call initialize() first.');
    }
    return _webApi!;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
    _webApi = null;
  }

  // Generic CRUD operations
  Future<int> insert(String table, Map<String, dynamic> data) async {
    if (kIsWeb) {
      // Web implementation using API service
      if (table == 'playlists') {
        final result = await _webApi!.createPlaylist(
          name: data['name'] as String,
          url: data['url'] as String?,
        );
        // Handle the response format: {"id": 1, "message": "Playlist created successfully"}
        if (result.containsKey('id')) {
          return result['id'] as int;
        } else {
          throw Exception('Invalid API response: missing id field');
        }
      } else {
        throw UnimplementedError('Web API insert not implemented for table: $table');
      }
    } else {
      return await db.insert(table, data);
    }
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    if (kIsWeb) {
      // Web implementation using API service
      switch (table) {
        case 'playlists':
          return await _webApi!.getPlaylists();
        case 'channels':
          return await _webApi!.getChannels();
        case 'favorites':
          return await _webApi!.getFavorites();
        case 'watch_history':
          return await _webApi!.getHistory();
        default:
          throw UnimplementedError('Web API query not implemented for table: $table');
      }
    } else {
      return await db.query(
        table,
        where: where,
        whereArgs: whereArgs,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );
    }
  }

  Future<int> update(
    String table,
    Map<String, dynamic> data, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    if (kIsWeb) {
      // Web implementation using API service
      throw UnimplementedError('Web API update not implemented for table: $table');
    } else {
      return await db.update(table, data, where: where, whereArgs: whereArgs);
    }
  }

  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    if (kIsWeb) {
      // Web implementation using API service
      throw UnimplementedError('Web API delete not implemented for table: $table');
    } else {
      return await db.delete(table, where: where, whereArgs: whereArgs);
    }
  }

  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<Object?>? arguments]) async {
    if (kIsWeb) {
      // For Web, implement specific queries that are commonly used
      debugPrint('DatabaseHelper: Raw query on Web: $sql');
      
      // Handle channel count and group statistics
      if (sql.contains('SELECT COUNT(*) as count, COUNT(DISTINCT group_name) as groups')) {
        try {
          final channels = await _webApi!.getChannels();
          final groups = channels.map((ch) => ch['group_name']).where((g) => g != null).toSet();
          return [{'count': channels.length, 'groups': groups.length}];
        } catch (e) {
          debugPrint('DatabaseHelper: Error getting channel stats: $e');
          return [{'count': 0, 'groups': 0}];
        }
      }
      
      // Handle favorites query
      if (sql.contains('SELECT c.* FROM channels c') && sql.contains('INNER JOIN favorites f')) {
        try {
          final favorites = await _webApi!.getFavorites();
          return favorites;
        } catch (e) {
          debugPrint('DatabaseHelper: Error getting favorites: $e');
          return [];
        }
      }
      
      // Default: return empty result for unsupported queries
      debugPrint('DatabaseHelper: Unsupported raw query on Web: $sql');
      return [];
    } else {
      return await db.rawQuery(sql, arguments);
    }
  }
}
