# Proxy Checker - 代理检测服务

一个用Go语言编写的HTTP服务，专门用于检测代理服务器是否可用。支持HTTP和SOCKS5代理，具有超时控制和详细的响应信息。

## 功能特性

- 支持HTTP/HTTPS代理检测
- 支持SOCKS5代理检测
- 可配置的超时时间（默认2秒）
- 可自定义测试URL（默认使用百度）
- 返回详细的检测结果和响应时间
- RESTful API接口
- 健康检查端点

## 快速开始

### 安装依赖

```bash
go mod tidy
```

### 启动服务

```bash
go run main.go
```

服务将在端口8080上启动。

### API接口

#### 健康检查
```bash
GET /health
```

#### 代理检测
```bash
POST /check
Content-Type: application/json

{
  "proxy_url": "socks5://username:password@host:port",
  "test_url": "https://www.baidu.com/" // 可选，默认使用百度
}
```

### 请求示例

#### 检测SOCKS5代理
```bash
curl -X POST http://localhost:8080/check \
  -H "Content-Type: application/json" \
  -d '{
    "proxy_url": "socks5://5B3AA05B:F9636FCFC9B4@60.188.79.124:20099"
  }'
```

#### 检测HTTP代理
```bash
curl -X POST http://localhost:8080/check \
  -H "Content-Type: application/json" \
  -d '{
    "proxy_url": "http://5B3AA05B:F9636FCFC9B4@60.188.79.124:20099"
  }'
```

#### 使用自定义测试URL
```bash
curl -X POST http://localhost:8080/check \
  -H "Content-Type: application/json" \
  -d '{
    "proxy_url": "http://username:password@proxy.example.com:8080",
    "test_url": "https://httpbin.org/ip"
  }'
```

### 响应格式

```json
{
  "success": true,
  "proxy_url": "socks5://username:password@host:port",
  "test_url": "https://www.baidu.com/",
  "status_code": 200,
  "duration_ms": 1205.5
}
```

失败时的响应：
```json
{
  "success": false,
  "proxy_url": "invalid-proxy-url",
  "test_url": "https://www.baidu.com/",
  "error": "代理URL格式错误: parse \"invalid-proxy-url\": invalid URI for request",
  "duration_ms": 0.1
}
```

### 测试脚本

项目包含一个测试脚本 `test_proxy.sh`，可以用来测试各种场景：

```bash
# 确保服务正在运行，然后执行：
./test_proxy.sh
```

## 支持的代理类型

- HTTP代理：`http://[username:password@]host:port`
- HTTPS代理：`https://[username:password@]host:port`
- SOCKS5代理：`socks5://[username:password@]host:port`

## 配置选项

- **默认超时时间**：2秒
- **默认测试URL**：https://www.baidu.com/
- **服务端口**：8080

可以通过修改 `main.go` 中的常量来调整这些配置。

## 构建和部署

### 构建二进制文件
```bash
go build -o proxy-checker main.go
```

### 运行二进制文件
```bash
./proxy-checker
```

## 注意事项

1. 确保代理服务器地址和端口正确
2. 检查用户名和密码是否正确
3. 某些代理服务器可能需要更长的超时时间
4. 测试URL需要是可访问的HTTP/HTTPS地址

## 错误处理

服务会返回详细的错误信息，包括：
- 代理URL格式错误
- 代理连接失败
- 目标网站无法访问
- 超时错误
- 不支持的代理类型

## 许可证

MIT License

