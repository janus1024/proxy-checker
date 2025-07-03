#!/bin/bash

# 代理检测服务部署脚本
# 支持CentOS 7/8/9
# 使用方法: sudo ./deploy.sh

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
SERVICE_NAME="proxy-checker"
SERVICE_USER="proxy-checker"
SERVICE_GROUP="proxy-checker"
INSTALL_DIR="/opt/proxy-checker"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
PORT=8080

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        log_info "请使用: sudo $0"
        exit 1
    fi
}

# 检查系统版本
check_system() {
    if [[ ! -f /etc/redhat-release ]]; then
        log_error "此脚本仅支持CentOS/RHEL系统"
        exit 1
    fi
    
    local version=$(cat /etc/redhat-release)
    log_info "检测到系统: $version"
}

# 检查二进制文件
check_binary() {
    log_info "检查二进制文件..."
    
    if [[ ! -f "$INSTALL_DIR/${SERVICE_NAME}" ]]; then
        log_error "二进制文件不存在: $INSTALL_DIR/${SERVICE_NAME}"
        log_info "请确保您已经将编译好的二进制文件上传到 $INSTALL_DIR/ 目录"
        exit 1
    fi
    
    if [[ ! -x "$INSTALL_DIR/${SERVICE_NAME}" ]]; then
        log_info "设置二进制文件执行权限..."
        chmod +x "$INSTALL_DIR/${SERVICE_NAME}"
    fi
    
    log_success "二进制文件检查通过"
}

# 创建服务用户
create_user() {
    log_info "创建服务用户..."
    
    if ! id "$SERVICE_USER" &>/dev/null; then
        useradd --system --no-create-home --shell /bin/false --user-group "$SERVICE_USER"
        log_success "用户 $SERVICE_USER 创建成功"
    else
        log_info "用户 $SERVICE_USER 已存在"
    fi
}

# 设置文件权限
set_permissions() {
    log_info "设置文件权限..."
    
    # 确保安装目录存在
    mkdir -p "$INSTALL_DIR"
    
    # 设置权限
    chown -R "$SERVICE_USER:$SERVICE_GROUP" "$INSTALL_DIR"
    chmod +x "$INSTALL_DIR/${SERVICE_NAME}"
    
    log_success "文件权限设置完成"
}

# 检查服务文件
check_service_file() {
    log_info "检查systemd服务文件..."
    
    if [[ ! -f "${SERVICE_NAME}.service" ]]; then
        log_error "systemd服务文件不存在: ${SERVICE_NAME}.service"
        log_info "请确保 ${SERVICE_NAME}.service 文件与此脚本在同一目录"
        exit 1
    fi
    
    log_success "服务文件检查通过"
}

# 安装systemd服务
install_service() {
    log_info "安装systemd服务..."
    
    # 复制服务文件
    cp "${SERVICE_NAME}.service" "$SERVICE_FILE"
    
    # 重新加载systemd配置
    systemctl daemon-reload
    
    # 启用服务
    systemctl enable "$SERVICE_NAME"
    
    log_success "服务安装完成"
}

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙..."
    
    if command -v firewall-cmd &> /dev/null; then
        if systemctl is-active --quiet firewalld; then
            firewall-cmd --permanent --add-port=${PORT}/tcp
            firewall-cmd --reload
            log_success "防火墙规则已添加 (端口 $PORT)"
        else
            log_warning "firewalld服务未运行，跳过防火墙配置"
        fi
    else
        log_warning "firewalld未安装，跳过防火墙配置"
    fi
}

# 启动服务
start_service() {
    log_info "启动服务..."
    
    systemctl start "$SERVICE_NAME"
    
    # 等待服务启动
    sleep 2
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log_success "服务启动成功"
    else
        log_error "服务启动失败"
        log_info "查看日志: journalctl -u $SERVICE_NAME -f"
        exit 1
    fi
}

# 测试服务
test_service() {
    log_info "测试服务..."
    
    sleep 3
    
    # 测试健康检查端点
    if curl -s "http://localhost:${PORT}/health" > /dev/null; then
        log_success "服务测试通过"
        log_info "健康检查URL: http://localhost:${PORT}/health"
        log_info "代理检测URL: http://localhost:${PORT}/check"
    else
        log_warning "服务测试失败，请检查日志"
        log_info "查看日志: journalctl -u $SERVICE_NAME -f"
    fi
}

# 显示状态信息
show_status() {
    echo
    log_info "=== 部署完成 ==="
    echo
    log_info "服务名称: $SERVICE_NAME"
    log_info "安装目录: $INSTALL_DIR"
    log_info "服务端口: $PORT"
    echo
    log_info "常用命令:"
    echo "  启动服务: sudo systemctl start $SERVICE_NAME"
    echo "  停止服务: sudo systemctl stop $SERVICE_NAME"
    echo "  重启服务: sudo systemctl restart $SERVICE_NAME"
    echo "  查看状态: sudo systemctl status $SERVICE_NAME"
    echo "  查看日志: sudo journalctl -u $SERVICE_NAME -f"
    echo "  禁用服务: sudo systemctl disable $SERVICE_NAME"
    echo
    log_info "API端点:"
    echo "  健康检查: curl http://localhost:${PORT}/health"
    echo "  代理检测: curl -X POST -H 'Content-Type: application/json' -d '{\"proxy_url\":\"socks5://user:pass@host:port\"}' http://localhost:${PORT}/check"
}

# 主函数
main() {
    log_info "开始部署代理检测服务..."
    
    check_root
    check_system
    check_service_file
    check_binary
    create_user
    set_permissions
    install_service
    configure_firewall
    start_service
    test_service
    show_status
    
    log_success "部署完成！"
}

# 错误处理
trap 'log_error "部署过程中发生错误，请检查日志"; exit 1' ERR

# 执行主函数
main "$@" 