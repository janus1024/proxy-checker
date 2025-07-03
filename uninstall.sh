#!/bin/bash

# 代理检测服务卸载脚本
# 使用方法: sudo ./uninstall.sh

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

# 确认卸载
confirm_uninstall() {
    echo
    log_warning "警告: 此操作将完全卸载代理检测服务"
    log_info "将执行以下操作:"
    echo "  - 停止并禁用服务"
    echo "  - 删除systemd服务文件"
    echo "  - 删除安装目录: $INSTALL_DIR"
    echo "  - 删除服务用户: $SERVICE_USER"
    echo "  - 移除防火墙规则"
    echo
    
    read -p "确定要继续吗？ (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "卸载已取消"
        exit 0
    fi
}

# 停止并禁用服务
stop_service() {
    log_info "停止并禁用服务..."
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        systemctl stop "$SERVICE_NAME"
        log_success "服务已停止"
    else
        log_info "服务已经停止"
    fi
    
    if systemctl is-enabled --quiet "$SERVICE_NAME"; then
        systemctl disable "$SERVICE_NAME"
        log_success "服务已禁用"
    else
        log_info "服务已经禁用"
    fi
}

# 删除服务文件
remove_service_file() {
    log_info "删除systemd服务文件..."
    
    if [[ -f "$SERVICE_FILE" ]]; then
        rm -f "$SERVICE_FILE"
        systemctl daemon-reload
        log_success "服务文件已删除"
    else
        log_info "服务文件不存在"
    fi
}

# 删除安装目录
remove_install_dir() {
    log_info "删除安装目录..."
    
    if [[ -d "$INSTALL_DIR" ]]; then
        rm -rf "$INSTALL_DIR"
        log_success "安装目录已删除"
    else
        log_info "安装目录不存在"
    fi
}

# 删除服务用户
remove_user() {
    log_info "删除服务用户..."
    
    if id "$SERVICE_USER" &>/dev/null; then
        userdel "$SERVICE_USER"
        log_success "用户 $SERVICE_USER 已删除"
    else
        log_info "用户 $SERVICE_USER 不存在"
    fi
}

# 移除防火墙规则
remove_firewall_rule() {
    log_info "移除防火墙规则..."
    
    if command -v firewall-cmd &> /dev/null; then
        if systemctl is-active --quiet firewalld; then
            if firewall-cmd --list-ports | grep -q "${PORT}/tcp"; then
                firewall-cmd --permanent --remove-port=${PORT}/tcp
                firewall-cmd --reload
                log_success "防火墙规则已移除 (端口 $PORT)"
            else
                log_info "防火墙规则不存在"
            fi
        else
            log_warning "firewalld服务未运行"
        fi
    else
        log_warning "firewalld未安装"
    fi
}

# 清理残留文件
cleanup_remaining() {
    log_info "清理残留文件..."
    
    # 清理可能的日志文件
    if [[ -d "/var/log/${SERVICE_NAME}" ]]; then
        rm -rf "/var/log/${SERVICE_NAME}"
        log_success "日志目录已清理"
    fi
    
    # 清理可能的配置文件
    if [[ -d "/etc/${SERVICE_NAME}" ]]; then
        rm -rf "/etc/${SERVICE_NAME}"
        log_success "配置目录已清理"
    fi
}

# 显示卸载完成信息
show_completion() {
    echo
    log_success "=== 卸载完成 ==="
    echo
    log_info "代理检测服务已完全卸载"
    log_info "系统已恢复到安装前的状态"
    echo
}

# 主函数
main() {
    log_info "开始卸载代理检测服务..."
    
    check_root
    confirm_uninstall
    stop_service
    remove_service_file
    remove_install_dir
    remove_user
    remove_firewall_rule
    cleanup_remaining
    show_completion
    
    log_success "卸载完成！"
}

# 执行主函数
main "$@" 