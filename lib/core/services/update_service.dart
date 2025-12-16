import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:version/version.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_update.dart';
import '../services/service_locator.dart';

class UpdateService {
  static const String _githubRepoUrl =
      'https://api.github.com/repos/shnulaa/FlutterIPTV/releases';
  static const String _githubReleasesUrl =
      'https://github.com/shnulaa/FlutterIPTV/releases';

  // 检查更新的间隔时间（小时）
  static const int _checkUpdateInterval = 24;

  // 缓存相关
  static const String _cacheKey = 'github_api_cache';
  static const Duration _cacheExpiry = Duration(hours: 1);
  
  // 下载锁，防止并发下载
  static bool _isDownloading = false;

  /// 检查是否有可用更新
  Future<AppUpdate?> checkForUpdates({bool forceCheck = false}) async {
    try {
      debugPrint('UPDATE: 开始检查更新...');
      
      // 如果不是强制检查，检查是否需要跳过
      if (!forceCheck) {
        final lastCheckTime = await _getLastCheckTime();
        final now = DateTime.now();
        if (lastCheckTime != null && 
            now.difference(lastCheckTime).inHours < _checkUpdateInterval) {
          debugPrint('UPDATE: 距离上次检查不足 $_checkUpdateInterval 小时，跳过检查');
          return null;
        }
      }

      // 保存本次检查时间
      await _saveCheckTime(DateTime.now());

      // 首先尝试从缓存获取
      if (!forceCheck) {
        final cachedRelease = await _getCachedRelease();
        if (cachedRelease != null) {
          debugPrint('UPDATE: 使用缓存数据');
          return cachedRelease;
        }
      }

      // 尝试从GitHub API获取（使用Token认证）
      final release = await _fetchFromGitHubApi();
      
      if (release != null) {
        // 缓存结果
        await _cacheRelease(release);
        return release;
      }

      debugPrint('UPDATE: 无法获取最新发布信息');
      return null;
    } catch (e) {
      debugPrint('UPDATE: 检查更新时发生错误: $e');
      return null;
    }
  }

  /// 从GitHub API获取发布信息
  Future<AppUpdate?> _fetchFromGitHubApi() async {
    try {
      // 获取GitHub Token
      final token = await _getGitHubToken();
      
      // 构建请求头
      final headers = {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'FlutterIPTV-App/1.1.1',
      };
      
      // 如果有Token，添加到请求头
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'token $token';
        // 在调试模式下不打印完整的Token，只打印长度和前后几位字符
        if (kDebugMode) {
          final tokenPreview = token.length > 10
            ? '${token.substring(0, 4)}...${token.substring(token.length - 4)}'
            : '****';
          debugPrint('UPDATE: 使用GitHub Token进行认证 (长度: ${token.length}, 预览: $tokenPreview)');
        }
      } else {
        debugPrint('UPDATE: 未找到GitHub Token，使用未认证请求');
      }

      final response = await http.get(
        Uri.parse(_githubRepoUrl),
        headers: headers,
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final List<dynamic> releases = json.decode(response.body);
        if (releases.isNotEmpty) {
          // 返回最新的非预发布版本
          for (final release in releases) {
            if (release['prerelease'] != true) {
              debugPrint('UPDATE: 成功获取GitHub Releases信息');
              return AppUpdate.fromJson(release);
            }
          }
          // 如果没有找到正式版本，返回第一个
          debugPrint('UPDATE: 找到预发布版本，使用第一个发布');
          return AppUpdate.fromJson(releases.first);
        }
      } else {
        debugPrint('UPDATE: GitHub API请求失败，状态码: ${response.statusCode}');
        debugPrint('UPDATE: 响应内容: ${response.body}');
      }
    } catch (e) {
      debugPrint('UPDATE: 获取发布信息时发生错误: $e');
    }

    return null;
  }

  /// 获取GitHub Token
  Future<String?> _getGitHubToken() async {
    try {
      // 首先尝试从编译时环境变量获取
      final compileTimeToken = String.fromEnvironment('GITHUB_TOKEN', defaultValue: '');
      if (compileTimeToken.isNotEmpty) {
        debugPrint('UPDATE: 使用编译时环境变量中的GitHub Token');
        return compileTimeToken;
      }

      // 然后尝试从运行时环境变量获取
      final envToken = Platform.environment['GITHUB_TOKEN'];
      if (envToken != null && envToken.isNotEmpty) {
        debugPrint('UPDATE: 使用运行时环境变量中的GitHub Token');
        return envToken;
      }

      // 最后尝试从加密的SharedPreferences获取
      final prefs = ServiceLocator.prefs;
      final encryptedToken = prefs.getString('encrypted_github_token');
      if (encryptedToken != null && encryptedToken.isNotEmpty) {
        try {
          // 简单的解密（仅用于混淆，不是真正的加密）
          final token = _decryptToken(encryptedToken);
          if (token.isNotEmpty) {
            debugPrint('UPDATE: 使用本地存储的GitHub Token');
            return token;
          }
        } catch (e) {
          debugPrint('UPDATE: 解密GitHub Token失败: $e');
        }
      }

      debugPrint('UPDATE: 未找到GitHub Token');
      return null;
    } catch (e) {
      debugPrint('UPDATE: 获取GitHub Token失败: $e');
      return null;
    }
  }

  /// 保存GitHub Token（加密存储）
  Future<void> saveGitHubToken(String token) async {
    try {
      final prefs = ServiceLocator.prefs;
      // 简单的加密（仅用于混淆，不是真正的加密）
      final encryptedToken = _encryptToken(token);
      await prefs.setString('encrypted_github_token', encryptedToken);
      debugPrint('UPDATE: GitHub Token已加密保存');
    } catch (e) {
      debugPrint('UPDATE: 保存GitHub Token失败: $e');
    }
  }

  /// 简单的Token加密（仅用于混淆，不是真正的加密）
  String _encryptToken(String token) {
    // 使用简单的XOR加密
    final key = 'FlutterIPTV_Key_2024';
    final bytes = token.codeUnits;
    final keyBytes = key.codeUnits;
    
    final encrypted = <int>[];
    for (int i = 0; i < bytes.length; i++) {
      encrypted.add(bytes[i] ^ keyBytes[i % keyBytes.length]);
    }
    
    return String.fromCharCodes(encrypted);
  }

  /// 简单的Token解密
  String _decryptToken(String encryptedToken) {
    try {
      // 使用相同的XOR解密
      final key = 'FlutterIPTV_Key_2024';
      final bytes = encryptedToken.codeUnits;
      final keyBytes = key.codeUnits;
      
      final decrypted = <int>[];
      for (int i = 0; i < bytes.length; i++) {
        decrypted.add(bytes[i] ^ keyBytes[i % keyBytes.length]);
      }
      
      return String.fromCharCodes(decrypted);
    } catch (e) {
      return '';
    }
  }

  /// 获取当前应用版本
  Future<String> getCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      debugPrint('UPDATE: 获取当前版本失败: $e');
      return '0.0.0';
    }
  }

  /// 下载更新文件
  Future<String?> downloadUpdate(
    String downloadUrl, {
    Function(double)? onProgress,
    Function(String)? onStatusChange,
    int retryCount = 0,
  }) async {
    const maxRetries = 2; // 限制重试次数，避免无限循环
    
    // 检查是否已经在下载中，防止并发下载
    if (_isDownloading) {
      debugPrint('UPDATE: 已有下载任务在进行中，跳过此次下载');
      onStatusChange?.call('已有下载任务在进行中...');
      return null;
    }
    
    _isDownloading = true;
    
    try {
      debugPrint('UPDATE: 开始下载更新: $downloadUrl (尝试 ${retryCount + 1}/$maxRetries)');
      onStatusChange?.call('准备下载...');

      // 获取临时目录
      final tempDir = await getTemporaryDirectory();
      final fileName = downloadUrl.split('/').last;
      final savePath = '${tempDir.path}/$fileName';

      // 创建Dio实例
      final dio = Dio();
      
      // 下载文件
      await dio.download(
        downloadUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            onProgress?.call(progress);
            onStatusChange?.call('下载中... ${(progress * 100).toStringAsFixed(1)}%');
          }
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 20), // 减少超时时间
          sendTimeout: const Duration(seconds: 20), // 减少发送超时时间
          headers: {
            'User-Agent': 'FlutterIPTV-App/1.1.1',
          },
        ),
      );

      debugPrint('UPDATE: 下载完成: $savePath');
      onStatusChange?.call('下载完成');
      return savePath;
    } catch (e) {
      debugPrint('UPDATE: 下载失败: $e');
      
      // 如果是网络错误且还有重试次数，则重试
      if (retryCount < maxRetries &&
          (e.toString().contains('Connection') ||
           e.toString().contains('Timeout') ||
           e.toString().contains('信号灯') ||
           e.toString().contains('SocketException'))) {
        debugPrint('UPDATE: 网络错误，正在重试... (${retryCount + 1}/$maxRetries)');
        onStatusChange?.call('网络错误，正在重试... (${retryCount + 1}/$maxRetries)');
        
        // 等待一段时间后重试
        await Future.delayed(Duration(seconds: 2 * (retryCount + 1)));
        
        return downloadUpdate(
          downloadUrl,
          onProgress: onProgress,
          onStatusChange: onStatusChange,
          retryCount: retryCount + 1,
        );
      }
      
      // 重试次数用完或不是网络错误，返回失败
      onStatusChange?.call('下载失败: ${e.toString().length > 100 ? '网络连接错误' : e}');
      return null;
    } finally {
      // 无论成功还是失败，都要释放锁
      _isDownloading = false;
    }
  }

  /// 获取最新发布的下载URL
  Future<String?> getDownloadUrl(AppUpdate update) async {
    try {
      // 不再使用缓存的下载URL，因为缓存的可能不是当前平台的
      
      // 从GitHub API获取详细信息
      final token = await _getGitHubToken();
      final headers = {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'FlutterIPTV-App/1.1.1',
      };
      
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'token $token';
      }

      final response = await http.get(
        Uri.parse('https://api.github.com/repos/shnulaa/FlutterIPTV/releases/tags/v${update.version}'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final releaseData = json.decode(response.body);
        final assets = releaseData['assets'] as List<dynamic>;
        
        if (assets.isNotEmpty) {
          debugPrint('UPDATE: 当前平台: ${Platform.operatingSystem}');
          
          // 根据当前平台查找对应的安装包
          for (final asset in assets) {
            final name = asset['name'] as String;
            debugPrint('UPDATE: 检查资源文件: $name');
            
            // Windows平台 - 优先查找Windows版本
            if (Platform.isWindows) {
              if (name.toLowerCase().contains('windows') ||
                  name.toLowerCase().endsWith('.exe') ||
                  name.toLowerCase().endsWith('.msi') ||
                  name.toLowerCase().endsWith('.zip')) {
                final downloadUrl = asset['browser_download_url'] as String;
                debugPrint('UPDATE: 找到Windows下载链接: $downloadUrl');
                return downloadUrl;
              }
            }
            
            // Android平台
            if (Platform.isAndroid) {
              if (name.toLowerCase().contains('android') || name.toLowerCase().endsWith('.apk')) {
                final downloadUrl = asset['browser_download_url'] as String;
                debugPrint('UPDATE: 找到Android下载链接: $downloadUrl');
                return downloadUrl;
              }
            }
          }
          
          // 如果没找到匹配的版本，返回第一个
          final downloadUrl = assets.first['browser_download_url'] as String;
          debugPrint('UPDATE: 未找到平台匹配的安装包，使用第一个下载链接: $downloadUrl');
          return downloadUrl;
        }
      }
      
      debugPrint('UPDATE: 无法获取下载URL，状态码: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('UPDATE: 获取下载URL失败: $e');
      return null;
    }
  }

  /// 安装更新文件
  Future<bool> installUpdate(String filePath) async {
    try {
      debugPrint('UPDATE: 开始安装更新: $filePath');
      
      // 在Windows上，直接运行exe文件或msi安装包
      if (Platform.isWindows) {
        if (filePath.endsWith('.exe')) {
          await Process.run(filePath, []);
          debugPrint('UPDATE: EXE安装程序已启动');
          return true;
        } else if (filePath.endsWith('.msi')) {
          await Process.run('msiexec', ['/i', filePath]);
          debugPrint('UPDATE: MSI安装程序已启动');
          return true;
        } else {
          // 尝试以默认方式打开文件
          await Process.run('start', [filePath], runInShell: true);
          debugPrint('UPDATE: 使用默认程序打开文件');
          return true;
        }
      }
      
      debugPrint('UPDATE: 不支持的文件类型或平台');
      return false;
    } catch (e) {
      debugPrint('UPDATE: 安装失败: $e');
      return false;
    }
  }

  /// 获取最后检查时间
  Future<DateTime?> _getLastCheckTime() async {
    try {
      final prefs = ServiceLocator.prefs;
      final timestamp = prefs.getInt('last_update_check');
      if (timestamp == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } catch (e) {
      debugPrint('UPDATE: 获取最后检查时间失败: $e');
      return null;
    }
  }

  /// 保存检查时间
  Future<void> _saveCheckTime(DateTime time) async {
    try {
      final prefs = ServiceLocator.prefs;
      await prefs.setInt('last_update_check', time.millisecondsSinceEpoch);
      debugPrint('UPDATE: 保存检查时间: $time');
    } catch (e) {
      debugPrint('UPDATE: 保存检查时间失败: $e');
    }
  }

  /// 缓存发布信息
  Future<void> _cacheRelease(AppUpdate release) async {
    try {
      final prefs = ServiceLocator.prefs;
      final cacheData = {
        'data': release.toJson(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString(_cacheKey, json.encode(cacheData));
      debugPrint('UPDATE: 发布信息已缓存');
    } catch (e) {
      debugPrint('UPDATE: 缓存发布信息失败: $e');
    }
  }

  /// 获取缓存的发布信息
  Future<AppUpdate?> _getCachedRelease() async {
    try {
      final prefs = ServiceLocator.prefs;
      final cacheString = prefs.getString(_cacheKey);
      if (cacheString == null) return null;

      final cacheData = json.decode(cacheString);
      final timestamp = cacheData['timestamp'] as int;
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      
      // 检查缓存是否过期
      if (DateTime.now().difference(cacheTime) > _cacheExpiry) {
        debugPrint('UPDATE: 缓存已过期');
        await prefs.remove(_cacheKey);
        return null;
      }

      debugPrint('UPDATE: 使用缓存数据，缓存时间: ${cacheTime.toLocal()}');
      return AppUpdate.fromJson(cacheData['data']);
    } catch (e) {
      debugPrint('UPDATE: 获取缓存失败: $e');
      return null;
    }
  }
}
