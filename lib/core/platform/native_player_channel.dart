import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'platform_detector.dart';
import '../services/epg_service.dart';
import '../../features/favorites/providers/favorites_provider.dart';
import '../../features/channels/providers/channel_provider.dart';

/// Service to launch native Android player via MethodChannel
class NativePlayerChannel {
  static const _channel = MethodChannel('com.flutteriptv/native_player');
  static bool _initialized = false;
  static Function? _onPlayerClosedCallback;
  static FavoritesProvider? _favoritesProvider;
  static ChannelProvider? _channelProvider;

  /// Set providers for favorite functionality
  static void setProviders(FavoritesProvider favoritesProvider, ChannelProvider channelProvider) {
    _favoritesProvider = favoritesProvider;
    _channelProvider = channelProvider;
  }

  /// Initialize the channel
  static void init() {
    if (_initialized) return;
    _initialized = true;

    // Web 端不支持原生播放器，跳过初始化
    if (kIsWeb) {
      debugPrint('NativePlayerChannel: Web platform detected, skipping native player initialization');
      return;
    }

    // Listen for player closed event from native
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPlayerClosed') {
        debugPrint('NativePlayerChannel: Player closed from native');
        _onPlayerClosedCallback?.call();
        _onPlayerClosedCallback = null;
      } else if (call.method == 'getEpgInfo') {
        // Native player requests EPG info for a channel
        final channelName = call.arguments['channelName'] as String?;
        final epgId = call.arguments['epgId'] as String?;
        return _getEpgInfo(epgId, channelName);
      } else if (call.method == 'toggleFavorite') {
        // Native player requests to toggle favorite
        final channelIndex = call.arguments['channelIndex'] as int?;
        return _toggleFavorite(channelIndex);
      } else if (call.method == 'isFavorite') {
        // Native player requests to check if channel is favorite
        final channelIndex = call.arguments['channelIndex'] as int?;
        return _isFavorite(channelIndex);
      }
    });
  }

  static Map<String, dynamic>? _getEpgInfo(String? epgId, String? channelName) {
    final epgService = EpgService();
    final currentProgram = epgService.getCurrentProgram(epgId, channelName);
    final nextProgram = epgService.getNextProgram(epgId, channelName);

    if (currentProgram == null && nextProgram == null) return null;

    return {
      'currentTitle': currentProgram?.title,
      'currentRemaining': currentProgram?.remainingMinutes,
      'nextTitle': nextProgram?.title,
    };
  }

  static Future<bool?> _toggleFavorite(int? channelIndex) async {
    if (channelIndex == null || _favoritesProvider == null || _channelProvider == null) {
      debugPrint('NativePlayerChannel: toggleFavorite - invalid params: index=$channelIndex, favProv=${_favoritesProvider != null}, chanProv=${_channelProvider != null}');
      return null;
    }
    
    final channels = _channelProvider!.channels;
    if (channelIndex < 0 || channelIndex >= channels.length) {
      debugPrint('NativePlayerChannel: toggleFavorite - invalid index: $channelIndex, channels=${channels.length}');
      return null;
    }
    
    final channel = channels[channelIndex];
    debugPrint('NativePlayerChannel: toggleFavorite - channel: ${channel.name}, id: ${channel.id}');
    
    if (channel.id == null) {
      debugPrint('NativePlayerChannel: toggleFavorite - channel has no id');
      return null;
    }
    
    // Check current favorite status before toggle
    final wasFavorite = _favoritesProvider!.isFavorite(channel.id!);
    debugPrint('NativePlayerChannel: toggleFavorite - wasFavorite: $wasFavorite');
    
    // Toggle favorite
    final success = await _favoritesProvider!.toggleFavorite(channel);
    debugPrint('NativePlayerChannel: toggleFavorite - success: $success');
    
    if (!success) {
      return null;
    }
    
    // Return the new favorite status (opposite of what it was)
    final isFavoriteNow = !wasFavorite;
    debugPrint('NativePlayerChannel: toggleFavorite - isFavoriteNow: $isFavoriteNow');
    return isFavoriteNow;
  }

  static bool _isFavorite(int? channelIndex) {
    if (channelIndex == null || _favoritesProvider == null || _channelProvider == null) {
      debugPrint('NativePlayerChannel: isFavorite - invalid params: index=$channelIndex, favProv=${_favoritesProvider != null}, chanProv=${_channelProvider != null}');
      return false;
    }
    
    final channels = _channelProvider!.channels;
    if (channelIndex < 0 || channelIndex >= channels.length) {
      debugPrint('NativePlayerChannel: isFavorite - invalid index: $channelIndex, channels=${channels.length}');
      return false;
    }
    
    final channel = channels[channelIndex];
    if (channel.id == null) {
      debugPrint('NativePlayerChannel: isFavorite - channel has no id');
      return false;
    }
    
    final isFav = _favoritesProvider!.isFavorite(channel.id!);
    debugPrint('NativePlayerChannel: isFavorite - channel: ${channel.name}, isFavorite: $isFav');
    return isFav;
  }

  /// Check if native player is available (Android TV only)
  static Future<bool> isAvailable() async {
    // Web 端不支持原生播放器
    if (kIsWeb) return false;
    if (!PlatformDetector.isAndroid) return false;

    try {
      final result = await _channel.invokeMethod<bool>('isNativePlayerAvailable');
      return result ?? false;
    } catch (e) {
      debugPrint('NativePlayerChannel: isAvailable error: $e');
      return false;
    }
  }

  /// Launch native player with given URL, channel name, and optional channel list for switching
  /// Returns true if launched successfully
  static Future<bool> launchPlayer({
    required String url,
    String name = '',
    int index = 0,
    List<String>? urls,
    List<String>? names,
    List<String>? groups,
    List<List<String>>? sources, // 每个频道的所有源
    bool isDlnaMode = false,
    String bufferStrength = 'fast',
    bool showFps = true,
    bool showClock = true,
    bool showNetworkSpeed = true,
    bool showVideoInfo = true,
    Function? onClosed,
  }) async {
    try {
      init(); // Ensure initialized
      _onPlayerClosedCallback = onClosed;

      debugPrint('NativePlayerChannel: launching player with url=$url, name=$name, index=$index, channels=${urls?.length ?? 0}, isDlna=$isDlnaMode, buffer=$bufferStrength');
      final result = await _channel.invokeMethod<bool>('launchPlayer', {
        'url': url,
        'name': name,
        'index': index,
        'urls': urls,
        'names': names,
        'groups': groups,
        'sources': sources, // 传递每个频道的所有源
        'isDlnaMode': isDlnaMode,
        'bufferStrength': bufferStrength,
        'showFps': showFps,
        'showClock': showClock,
        'showNetworkSpeed': showNetworkSpeed,
        'showVideoInfo': showVideoInfo,
      });
      debugPrint('NativePlayerChannel: launch result=$result');
      return result ?? false;
    } catch (e) {
      debugPrint('NativePlayerChannel: launchPlayer error: $e');
      _onPlayerClosedCallback = null;
      return false;
    }
  }

  /// Close the native player
  static Future<void> closePlayer() async {
    try {
      await _channel.invokeMethod('closePlayer');
    } catch (e) {
      debugPrint('NativePlayerChannel: closePlayer error: $e');
    }
  }
  
  /// Pause the native player (for DLNA control)
  static Future<void> pause() async {
    try {
      await _channel.invokeMethod('pause');
    } catch (e) {
      debugPrint('NativePlayerChannel: pause error: $e');
    }
  }
  
  /// Resume/play the native player (for DLNA control)
  static Future<void> play() async {
    try {
      await _channel.invokeMethod('play');
    } catch (e) {
      debugPrint('NativePlayerChannel: play error: $e');
    }
  }
  
  /// Seek to position in milliseconds (for DLNA control)
  static Future<void> seekTo(int positionMs) async {
    try {
      await _channel.invokeMethod('seekTo', {'position': positionMs});
    } catch (e) {
      debugPrint('NativePlayerChannel: seekTo error: $e');
    }
  }
  
  /// Set volume (0-100) (for DLNA control)
  static Future<void> setVolume(int volume) async {
    try {
      await _channel.invokeMethod('setVolume', {'volume': volume});
    } catch (e) {
      debugPrint('NativePlayerChannel: setVolume error: $e');
    }
  }
  
  /// Get current playback state from native player
  static Future<Map<String, dynamic>?> getPlaybackState() async {
    try {
      final result = await _channel.invokeMethod<Map>('getPlaybackState');
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
    } catch (e) {
      debugPrint('NativePlayerChannel: getPlaybackState error: $e');
    }
    return null;
  }
}
