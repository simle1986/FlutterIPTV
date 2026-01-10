import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:http/http.dart' as http;
import 'package:sqlite3/sqlite3.dart';
import 'package:path/path.dart' as path;

class WebServer {
  late Database db;
  late Router router;

  Future<void> init() async {
    // Initialize SQLite database
    final dbPath = path.join(Directory.current.path, 'web_server', 'data', 'flutter_iptv_web.db');
    final dbDir = path.dirname(dbPath);
    
    // Create data directory if it doesn't exist
    await Directory(dbDir).create(recursive: true);
    
    db = sqlite3.open(dbPath);
    
    // Create tables
    _createTables();
    
    // Setup routes
    _setupRoutes();
  }

  void _createTables() {
    // Playlists table
    db.execute('''
      CREATE TABLE IF NOT EXISTS playlists (
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
    db.execute('''
      CREATE TABLE IF NOT EXISTS channels (
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
    db.execute('''
      CREATE TABLE IF NOT EXISTS favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        channel_id INTEGER NOT NULL,
        position INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (channel_id) REFERENCES channels(id) ON DELETE CASCADE
      )
    ''');

    // Watch history table
    db.execute('''
      CREATE TABLE IF NOT EXISTS watch_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        channel_id INTEGER NOT NULL,
        watched_at INTEGER NOT NULL,
        duration_seconds INTEGER DEFAULT 0,
        FOREIGN KEY (channel_id) REFERENCES channels(id) ON DELETE CASCADE
      )
    ''');

    // EPG data table
    db.execute('''
      CREATE TABLE IF NOT EXISTS epg_data (
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

    // Create indexes
    db.execute('CREATE INDEX IF NOT EXISTS idx_channels_playlist ON channels(playlist_id)');
    db.execute('CREATE INDEX IF NOT EXISTS idx_channels_group ON channels(group_name)');
    db.execute('CREATE INDEX IF NOT EXISTS idx_favorites_channel ON favorites(channel_id)');
    db.execute('CREATE INDEX IF NOT EXISTS idx_history_channel ON watch_history(channel_id)');
    db.execute('CREATE INDEX IF NOT EXISTS idx_epg_channel ON epg_data(channel_epg_id)');
    db.execute('CREATE INDEX IF NOT EXISTS idx_epg_time ON epg_data(start_time, end_time)');
  }

  void _setupRoutes() {
    router = Router();

    // CORS proxy for M3U files
    router.get('/api/proxy', _proxyHandler);
    
    // Playlist management
    router.get('/api/playlists', _getPlaylists);
    router.post('/api/playlists', _createPlaylist);
    router.put('/api/playlists/<id>', _updatePlaylist);
    router.delete('/api/playlists/<id>', _deletePlaylist);
    
    // Channel management
    router.get('/api/channels', _getChannels);
    router.get('/api/channels/playlist/<playlistId>', _getChannelsByPlaylist);
    
    // Favorites
    router.get('/api/favorites', _getFavorites);
    router.post('/api/favorites', _addFavorite);
    router.delete('/api/favorites/<id>', _removeFavorite);
    
    // Watch history
    router.get('/api/history', _getHistory);
    router.post('/api/history', _addHistory);
    
    // Health check
    router.get('/api/health', (Request request) {
      return Response.ok(jsonEncode({'status': 'ok', 'timestamp': DateTime.now().toIso8601String()}));
    });

    // Add a catch-all route for debugging
    router.all('/<path|.*>', (Request request) {
      print('Unhandled request: ${request.method} ${request.url}');
      return Response.notFound('Route not found: ${request.method} ${request.url}');
    });
  }

  // CORS proxy handler
  Future<Response> _proxyHandler(Request request) async {
    final url = request.url.queryParameters['url'];
    if (url == null || url.isEmpty) {
      return Response.badRequest(body: jsonEncode({'error': 'Missing url parameter'}));
    }

    try {
      print('Proxying request to: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        },
      ).timeout(const Duration(seconds: 30));

      return Response.ok(
        response.body,
        headers: {
          'Content-Type': 'text/plain; charset=utf-8',
        },
      );
    } catch (e) {
      print('Proxy error: $e');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to fetch URL: $e'}),
      );
    }
  }

  // Playlist handlers
  Future<Response> _getPlaylists(Request request) async {
    try {
      final results = db.select('SELECT * FROM playlists ORDER BY created_at DESC');
      final playlists = results.map((row) => {
        'id': row['id'],
        'name': row['name'],
        'url': row['url'],
        'file_path': row['file_path'],
        'is_active': row['is_active'], // Keep as integer (0 or 1)
        'last_updated': row['last_updated'],
        'channel_count': row['channel_count'],
        'created_at': row['created_at'],
      }).toList();

      return Response.ok(jsonEncode(playlists));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  Future<Response> _createPlaylist(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      
      final name = data['name'] as String?;
      final url = data['url'] as String?;
      
      if (name == null || name.isEmpty) {
        return Response.badRequest(body: jsonEncode({'error': 'Name is required'}));
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      
      final stmt = db.prepare('''
        INSERT INTO playlists (name, url, is_active, last_updated, channel_count, created_at)
        VALUES (?, ?, 1, ?, 0, ?)
      ''');
      
      stmt.execute([name, url, now, now]);
      final playlistId = db.lastInsertRowId;
      stmt.dispose();

      // If URL is provided, fetch and parse M3U content
      if (url != null && url.isNotEmpty) {
        await _fetchAndParseM3U(playlistId, url);
      }

      return Response.ok(jsonEncode({'id': playlistId, 'message': 'Playlist created successfully'}));
    } catch (e) {
      print('Create playlist error: $e');
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  Future<void> _fetchAndParseM3U(int playlistId, String url) async {
    try {
      print('Fetching M3U from: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final channels = _parseM3U(response.body, playlistId);
        await _saveChannels(channels);
        
        // Update playlist channel count
        final stmt = db.prepare('UPDATE playlists SET channel_count = ?, last_updated = ? WHERE id = ?');
        stmt.execute([channels.length, DateTime.now().millisecondsSinceEpoch, playlistId]);
        stmt.dispose();
        
        print('Successfully parsed ${channels.length} channels');
      } else {
        print('Failed to fetch M3U: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching M3U: $e');
    }
  }

  List<Map<String, dynamic>> _parseM3U(String content, int playlistId) {
    final channels = <Map<String, dynamic>>[];
    final lines = content.split('\n');
    
    String? currentName;
    String? currentLogo;
    String? currentGroup;
    String? currentEpgId;
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      
      if (line.startsWith('#EXTINF:')) {
        // Parse EXTINF line
        final parsed = _parseExtInf(line);
        currentName = parsed['name'];
        currentLogo = parsed['logo'];
        currentGroup = parsed['group'];
        currentEpgId = parsed['epgId'];
      } else if (line.isNotEmpty && !line.startsWith('#')) {
        // This is a URL line
        if (currentName != null && _isValidUrl(line)) {
          channels.add({
            'playlist_id': playlistId,
            'name': currentName,
            'url': line,
            'sources': jsonEncode([line]),
            'logo_url': currentLogo,
            'group_name': currentGroup ?? 'Uncategorized',
            'epg_id': currentEpgId,
            'is_active': 1,
            'created_at': DateTime.now().millisecondsSinceEpoch,
          });
        }
        
        // Reset for next entry
        currentName = null;
        currentLogo = null;
        currentGroup = null;
        currentEpgId = null;
      }
    }
    
    return channels;
  }

  Map<String, String?> _parseExtInf(String line) {
    String? name;
    String? logo;
    String? group;
    String? epgId;

    // Remove #EXTINF: prefix
    String content = line.substring(8);

    // Find the channel name (after the last comma)
    final lastCommaIndex = content.lastIndexOf(',');
    if (lastCommaIndex != -1) {
      name = content.substring(lastCommaIndex + 1).trim();
      content = content.substring(0, lastCommaIndex);
    }

    // Parse attributes using regex
    final attrRegex = RegExp(r'(\S+?)=["\u0027]?([^"\u0027]+)["\u0027]?(?:\s|$)');
    final matches = attrRegex.allMatches(content);
    
    for (final match in matches) {
      final key = match.group(1)?.toLowerCase();
      final value = match.group(2);
      
      if (key != null && value != null) {
        switch (key) {
          case 'tvg-logo':
          case 'logo':
            logo = value.trim();
            break;
          case 'group-title':
          case 'tvg-group':
            group = value.trim();
            break;
          case 'tvg-id':
          case 'tvg-name':
            epgId = value.trim();
            break;
        }
      }
    }

    return {
      'name': name,
      'logo': logo,
      'group': group,
      'epgId': epgId,
    };
  }

  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && 
          (uri.scheme == 'http' || uri.scheme == 'https' || 
           uri.scheme == 'rtmp' || uri.scheme == 'rtsp');
    } catch (e) {
      return false;
    }
  }

  Future<void> _saveChannels(List<Map<String, dynamic>> channels) async {
    final stmt = db.prepare('''
      INSERT INTO channels (playlist_id, name, url, sources, logo_url, group_name, epg_id, is_active, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''');
    
    for (final channel in channels) {
      stmt.execute([
        channel['playlist_id'],
        channel['name'],
        channel['url'],
        channel['sources'],
        channel['logo_url'],
        channel['group_name'],
        channel['epg_id'],
        channel['is_active'],
        channel['created_at'],
      ]);
    }
    
    stmt.dispose();
  }

  Future<Response> _updatePlaylist(Request request) async {
    // Implementation for updating playlist
    return Response.ok(jsonEncode({'message': 'Update playlist not implemented yet'}));
  }

  Future<Response> _deletePlaylist(Request request) async {
    // Implementation for deleting playlist
    return Response.ok(jsonEncode({'message': 'Delete playlist not implemented yet'}));
  }

  Future<Response> _getChannels(Request request) async {
    try {
      final results = db.select('SELECT * FROM channels ORDER BY name');
      final channels = results.map((row) => {
        'id': row['id'],
        'playlist_id': row['playlist_id'],
        'name': row['name'],
        'url': row['url'],
        'sources': row['sources'] != null ? jsonDecode(row['sources']) : [row['url']],
        'logo_url': row['logo_url'],
        'group_name': row['group_name'],
        'epg_id': row['epg_id'],
        'is_active': row['is_active'], // Keep as integer (0 or 1)
        'created_at': row['created_at'],
      }).toList();

      return Response.ok(jsonEncode(channels));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  Future<Response> _getChannelsByPlaylist(Request request) async {
    final playlistId = int.tryParse(request.params['playlistId'] ?? '');
    if (playlistId == null) {
      return Response.badRequest(body: jsonEncode({'error': 'Invalid playlist ID'}));
    }

    try {
      final results = db.select('SELECT * FROM channels WHERE playlist_id = ? ORDER BY name', [playlistId]);
      final channels = results.map((row) => {
        'id': row['id'],
        'playlist_id': row['playlist_id'],
        'name': row['name'],
        'url': row['url'],
        'sources': row['sources'] != null ? jsonDecode(row['sources']) : [row['url']],
        'logo_url': row['logo_url'],
        'group_name': row['group_name'],
        'epg_id': row['epg_id'],
        'is_active': row['is_active'], // Keep as integer (0 or 1)
        'created_at': row['created_at'],
      }).toList();

      return Response.ok(jsonEncode(channels));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  Future<Response> _getFavorites(Request request) async {
    // Implementation for getting favorites
    return Response.ok(jsonEncode([]));
  }

  Future<Response> _addFavorite(Request request) async {
    // Implementation for adding favorite
    return Response.ok(jsonEncode({'message': 'Add favorite not implemented yet'}));
  }

  Future<Response> _removeFavorite(Request request) async {
    // Implementation for removing favorite
    return Response.ok(jsonEncode({'message': 'Remove favorite not implemented yet'}));
  }

  Future<Response> _getHistory(Request request) async {
    // Implementation for getting history
    return Response.ok(jsonEncode([]));
  }

  Future<Response> _addHistory(Request request) async {
    // Implementation for adding history
    return Response.ok(jsonEncode({'message': 'Add history not implemented yet'}));
  }

  void dispose() {
    db.dispose();
  }
}

void main(List<String> args) async {
  final server = WebServer();
  await server.init();

  // Create a custom handler that checks for API routes first
  Future<Response> customHandler(Request request) async {
    print('Incoming request: ${request.method} ${request.url}');
    print('Request path: "${request.url.path}"');
    
    // Check if it's an API request
    if (request.url.path.startsWith('api/') || request.url.path.startsWith('/api/')) {
      print('Routing to API handler: ${request.url.path}');
      return await server.router.call(request);
    }
    
    // Otherwise, serve static files
    print('Routing to static handler: ${request.url.path}');
    final staticHandler = createStaticHandler('../build/web', defaultDocument: 'index.html');
    return await staticHandler(request);
  }

  // Create handler pipeline
  final handler = Pipeline()
      .addMiddleware(corsHeaders())
      .addMiddleware(logRequests())
      .addHandler(customHandler);

  // Start server
  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
  final serverInstance = await serve(handler, InternetAddress.anyIPv4, port);
  
  print('Flutter IPTV Web Server running on http://localhost:$port');
  print('API endpoints available at http://localhost:$port/api/');
  print('Web app available at http://localhost:$port/');
  
  // Handle shutdown gracefully
  ProcessSignal.sigint.watch().listen((_) {
    print('\nShutting down server...');
    server.dispose();
    serverInstance.close(force: true);
    exit(0);
  });
}