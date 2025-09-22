# HopSignal Docker 自动化部署

这个项目提供了基于 Docker 的 HopSignal 服务自动化部署方案，包含 GitHub Actions 自动构建和发布流程。

## 功能特性

- 🐳 完全容器化的 HopSignal 服务
- 🚀 GitHub Actions 自动构建和发布
- 🔄 自动健康检查和服务恢复
- 📊 日志轮转管理
- 🌐 支持多架构构建 (amd64/arm64)
- 📝 详细的部署文档

## 快速开始

### 方法一：使用 Docker Compose (推荐)

1. 克隆仓库：
```bash
git clone <your-repository-url>
cd hopsignal-docker
```

2. 创建数据目录（如果使用本地目录挂载）：
```bash
mkdir -p data
# fedlist.txt 文件会在容器启动时自动创建
```

3. 启动服务：
```bash
docker-compose up -d
```

### 方法二：使用预构建的 Docker 镜像

```bash
# 拉取最新镜像
docker pull ghcr.io/<your-username>/<your-repository>/hopsignal:latest

# 运行容器
docker run -d \
  --name hopsignal \
  --restart unless-stopped \
  -p 80:80 \
  -p 82:82 \
  -v $(pwd)/data:/home/hopsignal/data \
  ghcr.io/<your-username>/<your-repository>/hopsignal:latest
```

### 方法三：本地构建

```bash
# 构建镜像
docker build -t hopsignal:local .

# 运行容器
docker run -d \
  --name hopsignal \
  --restart unless-stopped \
  -p 80:80 \
  -p 82:82 \
  hopsignal:local
```

## GitHub Actions 自动化

### 设置步骤

1. **Fork 或克隆此仓库**

2. **启用 GitHub Actions**
   - 进入仓库的 Settings → Actions → General
   - 选择 "Allow all actions and reusable workflows"

3. **配置容器注册表权限**
   - 进入 Settings → Actions → General → Workflow permissions
   - 选择 "Read and write permissions"
   - 勾选 "Allow GitHub Actions to create and approve pull requests"

4. **触发构建**
   - 推送代码到 `main` 分支将触发自动构建
   - 创建标签（如 `v1.0.0`）将构建带版本号的镜像
   - Pull Request 将构建测试镜像

### 构建触发条件

- **推送到 main/develop 分支**：构建 `latest` 标签
- **创建标签**：构建版本化标签（如 `v1.0.0`, `1.0`）
- **Pull Request**：构建测试镜像

## 配置说明

### 环境变量

| 变量名 | 默认值 | 描述 |
|--------|--------|------|
| `HOPSIGNAL_ADDR` | `0.0.0.0:80` | HopSignal 监听地址 |
| `HOPSIGNAL_FEDADDR` | `0.0.0.0:82` | Federation 监听地址 |
| `HOPSIGNAL_FEDPWD` | `123456789` | Federation 密码 |
| `TZ` | `UTC` | 时区设置 |

### 端口说明

- **端口 80**：主服务端口，用于客户端连接
- **端口 82**：Federation 端口，用于服务器间通信

### 数据持久化

容器设计为将所有持久化数据存储在 `/home/hopsignal/data` 目录中：

- `/home/hopsignal/data/hs.log`：服务日志文件
- `/home/hopsignal/data/fedlist.txt`：Federation 服务器列表

**推荐的挂载方式：**

```bash
# 使用 Docker 命名卷（推荐）
docker run -d \
  --name hopsignal \
  --restart unless-stopped \
  -p 80:80 -p 82:82 \
  -v hopsignal-data:/home/hopsignal/data \
  ghcr.io/<your-username>/<your-repository>/hopsignal:latest

# 或使用本地目录挂载
docker run -d \
  --name hopsignal \
  --restart unless-stopped \
  -p 80:80 -p 82:82 \
  -v $(pwd)/data:/home/hopsignal/data \
  ghcr.io/<your-username>/<your-repository>/hopsignal:latest
```

## 健康检查

容器包含内置的健康检查机制：
- **HTTP 检查**：每 30 秒检查服务状态
- **进程监控**：每分钟检查进程是否运行
- **WebSocket 检查**：检查 WebSocket 连接是否正常
- **日志轮转**：当日志文件超过 100MB 时自动重启服务

## HopToDesk 客户端配置

服务启动后，在 HopToDesk 客户端中使用以下配置：

### 方法一：API 文件配置

创建 `api.json` 文件：

```json
{
  "turnservers": [
    {
      "protocol": "turn",
      "host": "turn.hoptodesk.com",
      "port": "443",
      "username": "hoptodesk",
      "password": "hoptodesk1234"
    }
  ],
  "rendezvous": {
    "host": "YOUR_SERVER_IP",
    "port": "80"
  },
  "winversion": "1.0.0",
  "macversion": "1.0.0",
  "linuxversion": "1.0.0",
  "none": "none"
}
```

### 方法二：网络选择

在 HopToDesk 的"选择网络"区域中输入您的 API 文件 URL。

## 故障排除

### 查看日志

```bash
# 查看容器日志
docker logs hopsignal

# 实时查看日志
docker logs -f hopsignal
```

### 重启服务

```bash
# 重启容器
docker restart hopsignal

# 或使用 docker-compose
docker-compose restart
```

### 检查服务状态

```bash
# 检查容器状态
docker ps | grep hopsignal

# 检查健康状态
docker inspect hopsignal | grep Health -A 10
```

## 网络要求

确保以下端口在防火墙中开放：
- **TCP 80**：HopSignal 主服务
- **TCP 82**：Federation 服务

## 贡献

欢迎提交 Issue 和 Pull Request 来改进这个项目。

## 许可证

本项目遵循 MIT 许可证。详见 [LICENSE](LICENSE) 文件。

## 相关链接

- [HopToDesk 官网](https://www.hoptodesk.com/)
- [HopToDesk 帮助文档](https://help.hoptodesk.com/)
- [Docker Hub](https://hub.docker.com/)
- [GitHub Actions 文档](https://docs.github.com/en/actions)