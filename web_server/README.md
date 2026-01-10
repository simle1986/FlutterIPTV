# Flutter IPTV Web Server

这是Flutter IPTV应用的Web后端服务器，解决了Web版本的跨域访问和数据存储问题。

## 功能特性

- **CORS代理服务**：解决Web端访问M3U播放列表的跨域问题
- **SQLite数据库**：提供真正的数据库存储，而不是localStorage
- **RESTful API**：完整的播放列表和频道管理API
- **静态文件服务**：同时提供Flutter Web应用的静态文件服务

## 快速开始

### 1. 安装依赖

确保已安装Dart SDK，然后运行：

```bash
dart pub get
```

### 2. 启动服务器

**Windows:**
```cmd
run_server.bat
```

**Linux/macOS:**
```bash
chmod +x run_server.sh
./run_server.sh
```

**或者直接使用Dart:**
```bash
dart run bin/server.dart
```

### 3. 访问应用

服务器启动后，在浏览器中访问：
- Web应用：http://localhost:8080
- API文档：http://localhost:8080/api/health

## API接口

### 播放列表管理

- `GET /api/playlists` - 获取所有播放列表
- `POST /api/playlists` - 创建新播放列表
- `PUT /api/playlists/{id}` - 更新播放列表
- `DELETE /api/playlists/{id}` - 删除播放列表

### 频道管理

- `GET /api/channels` - 获取所有频道
- `GET /api/channels/playlist/{playlistId}` - 获取指定播放列表的频道

### CORS代理

- `GET /api/proxy?url={m3u_url}` - 代理获取M3U文件内容

### 其他功能

- `GET /api/favorites` - 获取收藏频道
- `POST /api/favorites` - 添加收藏
- `GET /api/history` - 获取观看历史
- `POST /api/history` - 添加观看记录

## 数据存储

数据库文件存储在 `data/flutter_iptv_web.db`，包含以下表：

- `playlists` - 播放列表
- `channels` - 频道信息
- `favorites` - 收藏频道
- `watch_history` - 观看历史
- `epg_data` - EPG节目单数据

## 配置

默认配置：
- 端口：8080
- 数据库：SQLite (data/flutter_iptv_web.db)
- 静态文件：../build/web

可以通过环境变量 `PORT` 修改端口：
```bash
PORT=3000 dart run bin/server.dart
```

## 开发说明

### 项目结构

```
web_server/
├── bin/
│   └── server.dart          # 主服务器文件
├── data/                    # 数据库文件目录
├── pubspec.yaml            # 依赖配置
├── run_server.bat          # Windows启动脚本
├── run_server.sh           # Linux/macOS启动脚本
└── README.md               # 说明文档
```

### 添加新API

1. 在 `_setupRoutes()` 方法中添加路由
2. 实现对应的处理方法
3. 更新数据库schema（如需要）

## 部署

### 生产环境部署

1. 构建Flutter Web应用：
```bash
flutter build web --release
```

2. 启动服务器：
```bash
dart compile exe bin/server.dart -o flutter_iptv_server
./flutter_iptv_server
```

### Docker部署

可以创建Dockerfile来容器化部署：

```dockerfile
FROM dart:stable AS build
WORKDIR /app
COPY pubspec.yaml ./
RUN dart pub get
COPY . .
RUN dart compile exe bin/server.dart -o server

FROM debian:stable-slim
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=build /app/server /app/server
COPY --from=build /app/build/web /app/web
WORKDIR /app
EXPOSE 8080
CMD ["./server"]
```

## 故障排除

### 常见问题

1. **端口被占用**
   - 修改端口：`PORT=3001 dart run bin/server.dart`
   - 或者停止占用端口的程序

2. **数据库权限问题**
   - 确保 `data` 目录有写权限
   - 检查磁盘空间

3. **CORS问题**
   - 服务器已配置CORS头，应该不会有跨域问题
   - 如果仍有问题，检查浏览器控制台错误

4. **M3U获取失败**
   - 检查目标URL是否可访问
   - 查看服务器日志了解具体错误

### 日志查看

服务器会在控制台输出详细日志，包括：
- 请求日志
- 数据库操作
- 错误信息
- M3U解析过程

## 许可证

与主项目相同的许可证。