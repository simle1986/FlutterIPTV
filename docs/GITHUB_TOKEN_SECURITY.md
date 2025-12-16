# GitHub Token 安全使用指南

## 概述

本应用使用GitHub Token来访问GitHub API，以检查应用更新和下载新版本。为了确保Token的安全性，我们实施了以下安全措施。

## Token获取方式

1. **编译时环境变量**（推荐）
   ```bash
   flutter build apk --dart-define=GITHUB_TOKEN=your_token_here
   ```

2. **运行时环境变量**
   ```bash
   export GITHUB_TOKEN=your_token_here
   flutter run
   ```

3. **应用内加密存储**
   - 用户可以在应用设置中输入Token
   - Token会被加密后存储在本地

## 安全措施

### 1. Token加密存储
- 使用XOR算法对Token进行加密存储
- 加密密钥硬编码在应用中，仅用于混淆而非真正的加密
- 存储键名为`encrypted_github_token`而非明文

### 2. 调试日志保护
- 在调试模式下，不会打印完整的Token
- 只显示Token长度和前后几位字符作为预览
- 格式：`长度: 40, 预览: ghp_****`

### 3. 优先级机制
Token获取按以下优先级进行：
1. 编译时环境变量（最安全）
2. 运行时环境变量
3. 本地加密存储（用户手动输入）

### 4. 错误处理
- 加密/解密失败时不会泄露Token
- 网络请求失败不会暴露Token

## 最佳实践

### 开发环境
1. 使用环境变量而非硬编码Token
2. 不要在版本控制中提交Token
3. 使用最小权限的Token（只读访问仓库）

### 生产环境
1. 在CI/CD中使用加密的环境变量
2. 定期轮换Token
3. 使用专用的服务账户Token

### Token权限
建议使用具有以下权限的Token：
- `public_repo` - 访问公共仓库
- `read:packages` - 读取包信息（如果需要）

## 创建Token步骤

1. 访问 GitHub Settings > Developer settings > Personal access tokens
2. 点击"Generate new token"
3. 设置Token名称（如"FlutterIPTV-Updater"）
4. 选择适当的权限（最少权限原则）
5. 设置过期时间
6. 复制生成的Token（仅显示一次）

## 注意事项

1. **永远不要**在代码中硬编码Token
2. **永远不要**提交Token到版本控制系统
3. 定期检查Token的使用情况
4. 如怀疑Token泄露，立即撤销并创建新Token

## 技术实现细节

### 加密算法
使用简单的XOR加密：
```dart
String _encryptToken(String token) {
  final key = 'FlutterIPTV_Key_2024';
  final bytes = token.codeUnits;
  final keyBytes = key.codeUnits;
  
  final encrypted = <int>[];
  for (int i = 0; i < bytes.length; i++) {
    encrypted.add(bytes[i] ^ keyBytes[i % keyBytes.length]);
  }
  
  return String.fromCharCodes(encrypted);
}
```

### Token获取逻辑
```dart
Future<String?> _getGitHubToken() async {
  // 1. 编译时环境变量
  final compileTimeToken = String.fromEnvironment('GITHUB_TOKEN', defaultValue: '');
  
  // 2. 运行时环境变量
  final envToken = Platform.environment['GITHUB_TOKEN'];
  
  // 3. 本地加密存储
  final encryptedToken = prefs.getString('encrypted_github_token');
  
  // 返回第一个有效的Token
}
```

## 更新记录

- **v1.1.15**: 移除了不安全的配置文件读取方式，实现了加密存储
- **v1.1.14**: 实现了基本的Token认证机制