import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Web API service for communicating with the backend server
class WebApiService {
  static const String _baseUrl = kDebugMode 
      ? 'http://localhost:8080/api' 
      : '/api'; // Use relative path in production

  /// Fetch M3U content through backend proxy
  Future<String> fetchM3UContent(String url) async {
    try {
      debugPrint('WebAPI: Fetching M3U through backend proxy: $url');
      
      final uri = Uri.parse('$_baseUrl/proxy').replace(queryParameters: {'url': url});
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        debugPrint('WebAPI: Successfully fetched M3U content, size: ${response.body.length}');
        return response.body;
      } else {
        throw Exception('Failed to fetch M3U: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('WebAPI: Error fetching M3U content: $e');
      rethrow;
    }
  }

  /// Get all playlists
  Future<List<Map<String, dynamic>>> getPlaylists() async {
    try {
      debugPrint('WebAPI: Getting playlists...');
      final uri = Uri.parse('$_baseUrl/playlists');
      final response = await http.get(uri);
      
      debugPrint('WebAPI: Playlists response: ${response.statusCode}');
      debugPrint('WebAPI: Playlists data: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        throw Exception('Failed to get playlists: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('WebAPI: Error getting playlists: $e');
      debugPrint('WebAPI: Error type: ${e.runtimeType}');
      rethrow;
    }
  }

  /// Create a new playlist
  Future<Map<String, dynamic>> createPlaylist({
    required String name,
    String? url,
  }) async {
    try {
      debugPrint('WebAPI: Creating playlist: $name, URL: $url');
      
      final uri = Uri.parse('$_baseUrl/playlists');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'url': url,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('WebAPI: Playlist created successfully: $data');
        return data;
      } else {
        throw Exception('Failed to create playlist: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('WebAPI: Error creating playlist: $e');
      rethrow;
    }
  }

  /// Get channels by playlist ID
  Future<List<Map<String, dynamic>>> getChannelsByPlaylist(int playlistId) async {
    try {
      final uri = Uri.parse('$_baseUrl/channels/playlist/$playlistId');
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        throw Exception('Failed to get channels: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('WebAPI: Error getting channels: $e');
      rethrow;
    }
  }

  /// Get all channels
  Future<List<Map<String, dynamic>>> getChannels() async {
    try {
      final uri = Uri.parse('$_baseUrl/channels');
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        throw Exception('Failed to get all channels: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('WebAPI: Error getting all channels: $e');
      rethrow;
    }
  }

  /// Get favorites
  Future<List<Map<String, dynamic>>> getFavorites() async {
    try {
      final uri = Uri.parse('$_baseUrl/favorites');
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        throw Exception('Failed to get favorites: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('WebAPI: Error getting favorites: $e');
      rethrow;
    }
  }

  /// Add favorite
  Future<void> addFavorite(int channelId) async {
    try {
      final uri = Uri.parse('$_baseUrl/favorites');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'channel_id': channelId}),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to add favorite: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('WebAPI: Error adding favorite: $e');
      rethrow;
    }
  }

  /// Remove favorite
  Future<void> removeFavorite(int favoriteId) async {
    try {
      final uri = Uri.parse('$_baseUrl/favorites/$favoriteId');
      final response = await http.delete(uri);
      
      if (response.statusCode != 200) {
        throw Exception('Failed to remove favorite: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('WebAPI: Error removing favorite: $e');
      rethrow;
    }
  }

  /// Get watch history
  Future<List<Map<String, dynamic>>> getHistory() async {
    try {
      final uri = Uri.parse('$_baseUrl/history');
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        throw Exception('Failed to get history: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('WebAPI: Error getting history: $e');
      rethrow;
    }
  }

  /// Add to watch history
  Future<void> addHistory({
    required int channelId,
    int durationSeconds = 0,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/history');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'channel_id': channelId,
          'duration_seconds': durationSeconds,
        }),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to add history: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('WebAPI: Error adding history: $e');
      rethrow;
    }
  }

  /// Health check
  Future<bool> healthCheck() async {
    try {
      final uri = Uri.parse('$_baseUrl/health');
      final response = await http.get(uri);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('WebAPI: Health check failed: $e');
      return false;
    }
  }
}