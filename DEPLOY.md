# CentOS 部署说明

本文档介绍如何在 CentOS 系统上部署代理检测服务，实现开机自动启动。

## 前提条件

- CentOS 7/8/9 系统
- root 权限
- 已编译好的二进制文件

## 部署步骤

### 1. 准备文件

确保以下文件在同一目录：
- `proxy-checker` (编译好的二进制文件)
- `proxy-checker.service` (systemd 服务文件)
- `deploy.sh` (部署脚本)
- `uninstall.sh` (卸载脚本)

### 2. 上传二进制文件

将编译好的 `proxy-checker` 二进制文件上传到服务器的 `/opt/proxy-checker/` 目录：

```bash
# 创建目录
sudo mkdir -p /opt/proxy-checker

# 上传二进制文件（使用 scp、rsync 或其他方式）
sudo cp proxy-checker /opt/proxy-checker/

# 设置执行权限
sudo chmod +x /opt/proxy-checker/proxy-checker
```

### 3. 执行部署脚本

```bash
# 给脚本添加执行权限
chmod +x deploy.sh

# 运行部署脚本
sudo ./deploy.sh
```

部署脚本会自动执行以下操作：
- 检查系统版本
- 验证二进制文件存在
- 创建服务用户 `proxy-checker`
- 设置文件权限
- 安装 systemd 服务
- 配置防火墙规则（开放 8080 端口）
- 启动服务
- 测试服务是否正常运行

### 4. 验证部署

部署完成后，可以通过以下方式验证：

```bash
# 检查服务状态
sudo systemctl status proxy-checker

# 查看服务日志
sudo journalctl -u proxy-checker -f

# 测试健康检查接口
curl http://localhost:8080/health

# 测试代理检测接口
curl -X POST -H 'Content-Type: application/json' \
  -d '{"proxy_url":"socks5://user:pass@host:port"}' \
  http://localhost:8080/check
```

## 服务管理

### 常用命令

```bash
# 启动服务
sudo systemctl start proxy-checker

# 停止服务
sudo systemctl stop proxy-checker

# 重启服务
sudo systemctl restart proxy-checker

# 查看服务状态
sudo systemctl status proxy-checker

# 查看实时日志
sudo journalctl -u proxy-checker -f

# 禁用开机自启
sudo systemctl disable proxy-checker

# 启用开机自启
sudo systemctl enable proxy-checker
```

### 配置文件位置

- 二进制文件：`/opt/proxy-checker/proxy-checker`
- systemd 服务文件：`/etc/systemd/system/proxy-checker.service`
- 服务用户：`proxy-checker`
- 服务端口：`8080`

## API 使用

### 健康检查

```bash
GET http://localhost:8080/health
```

响应：
```json
{"status": "ok"}
```

### 代理检测

```bash
POST http://localhost:8080/check
Content-Type: application/json

{
  "proxy_url": "socks5://username:password@host:port",
  "test_url": "https://www.baidu.com/"  // 可选，默认使用 baidu.com
}
```

响应示例：
```json
{
  "success": true,
  "proxy_url": "socks5://username:password@host:port",
  "test_url": "https://www.baidu.com/",
  "status_code": 200,
  "duration_ms": 1234.56
}
```

## 卸载服务

如需完全移除服务，运行卸载脚本：

```bash
sudo ./uninstall.sh
```

卸载脚本会：
- 停止并禁用服务
- 删除 systemd 服务文件
- 删除安装目录
- 删除服务用户
- 移除防火墙规则

## 故障排除

### 服务启动失败

1. 检查二进制文件是否存在且有执行权限：
```bash
ls -la /opt/proxy-checker/proxy-checker
```

2. 查看详细日志：
```bash
sudo journalctl -u proxy-checker -n 50
```

3. 检查端口是否被占用：
```bash
sudo netstat -tlnp | grep 8080
```

### 防火墙问题

如果外部无法访问服务，检查防火墙设置：

```bash
# 检查防火墙状态
sudo firewall-cmd --state

# 查看开放的端口
sudo firewall-cmd --list-ports

# 手动开放端口
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --reload
```

### 权限问题

确保服务用户有正确的权限：

```bash
sudo chown -R proxy-checker:proxy-checker /opt/proxy-checker
sudo chmod +x /opt/proxy-checker/proxy-checker
```

## 注意事项

1. 服务默认监听 `0.0.0.0:8080`，请确保防火墙配置正确
2. 服务使用 `proxy-checker` 用户运行，提高安全性
3. 日志通过 systemd journal 管理，使用 `journalctl` 查看
4. 服务配置了自动重启，异常退出后会自动恢复
5. 建议定期检查服务状态和日志 