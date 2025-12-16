class GitHubConfig {
  static const String githubToken = String.fromEnvironment(
    'GITHUB_TOKEN',
    defaultValue: '',
  );
  
  // 尝试从多个来源获取Token
  static String get getToken {
    // 优先使用环境变量中的Token
    if (githubToken.isNotEmpty) {
      return githubToken;
    }
    
    // 如果环境变量为空，返回空字符串
    // 在CI/CD环境中，应该通过环境变量设置Token
    return '';
  }
}