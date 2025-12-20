#!/bin/bash
set -u
set -o pipefail

# ============================================================
#  Docker Proxy Expert v9.0 (Auto-Detect Edition)
# ============================================================
# v9.0 更新说明：
# 1. [UX] 输入简化：支持仅输入 "IP:端口"，脚本自动探测协议。
# 2. [AUTO] 自动尝试 HTTP -> 失败则尝试 SOCKS5 -> 成功则自动配置桥接。
# 3. [FIX] 继承 v8.3 的所有 Buildx 解析和清理修复。

# --- 全局配置 ---
: "${GOST_VER:=2.11.5}"
: "${BRIDGE_PORT:=2378}"
: "${TEST_TARGET:=https://www.google.com}" # 探测连通性的目标

# --- 路径与变量 ---
CURRENT_USER=$(id -un 2>/dev/null || echo "root")
REAL_USER="${SUDO_USER:-$CURRENT_USER}"
if [ "$REAL_USER" = "root" ]; then REAL_HOME="/root"; else REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6); fi

SYSTEMD_PROXY_DIR="/etc/systemd/system/docker.service.d"
SYSTEMD_PROXY_FILE="$SYSTEMD_PROXY_DIR/http-proxy.conf"
CLIENT_CONFIG_FILE="$REAL_HOME/.docker/config.json"
BRIDGE_SERVICE_FILE="/etc/systemd/system/docker-socks-bridge.service"
GOST_BIN="/usr/local/bin/docker-gost"
WORK_DIR=$(mktemp -d) || exit 1

EFFECTIVE_HTTP_PROXY=""

# --- 颜色与辅助 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

trap 'rm -rf "$WORK_DIR"' EXIT

info() { echo -e "${CYAN}[INFO]${NC} $1"; }
pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; }
fatal() { echo -e "${RED}[FATAL]${NC} $1"; exit 1; }
ensure_dir() { if [ ! -d "$1" ]; then mkdir -p "$1"; fi; }

# --- 核心 1: 智能探测与代理校验 ---

ask_and_verify_proxy() {
    echo "------------------------------------------------"
    info "设置代理 (只需输入 IP:端口，回车跳过)"
    echo "格式示例: 192.168.0.142:7890 (脚本将自动探测是 HTTP 还是 SOCKS)"
    
    local def_proxy="${HTTP_PROXY:-${http_proxy:-}}"
    local prompt="请输入代理地址"
    # 如果环境里有代理，尝试提取纯 IP:Port 显示
    if [ -n "$def_proxy" ]; then
        local show_def="${def_proxy#*://}"
        prompt+=" (默认: $show_def)"
    fi
    
    local input_raw=""
    read -r -p "$prompt: " input_raw
    
    # 处理空输入
    if [ -z "$input_raw" ]; then
        if [ -n "$def_proxy" ]; then
            input_raw="$def_proxy"
        else
            info "用户跳过，未配置代理。"
            return 1
        fi
    fi

    # 1. 预处理：移除用户可能手输的 http:// 或 socks5:// 前缀，只保留 ip:port
    # 这样做是为了重新标准化探测，防止用户输错协议
    local clean_addr="${input_raw#*://}"
    
    info "正在探测代理协议 (目标: $clean_addr)..."

    # 2. 尝试探测 HTTP
    # -I: 只请求头, -s: 静默, connect-timeout: 3秒超时
    if curl -I -s --connect-timeout 3 --proxy "http://$clean_addr" "$TEST_TARGET" >/dev/null; then
        pass "探测成功：HTTP 协议"
        EFFECTIVE_HTTP_PROXY="http://$clean_addr"
        
    # 3. 尝试探测 SOCKS5
    elif curl -I -s --connect-timeout 3 --proxy "socks5://$clean_addr" "$TEST_TARGET" >/dev/null; then
        pass "探测成功：SOCKS5 协议"
        info "准备配置转换桥接..."
        
        if configure_socks_bridge "socks5://$clean_addr"; then
            # 桥接建立后，验证本地桥接端口
             if curl -I -s --connect-timeout 3 --proxy "http://127.0.0.1:$BRIDGE_PORT" "$TEST_TARGET" >/dev/null; then
                pass "SOCKS 桥接连通性测试通过！"
                EFFECTIVE_HTTP_PROXY="http://127.0.0.1:$BRIDGE_PORT"
            else
                systemctl stop docker-socks-bridge
                fatal "SOCKS 桥接服务启动了，但无法连接网络。请检查 SOCKS 代理服务器状态。"
            fi
        else
            fatal "SOCKS 桥接服务部署失败。"
        fi
        
    else
        # 4. 全部失败
        fail "探测失败！无法通过 HTTP 或 SOCKS5 连接到 $TEST_TARGET"
        echo "  - 请检查 IP 和端口是否正确"
        echo "  - 请检查防火墙是否允许连接"
        echo "  - 请确保代理软件已允许局域网连接 (Allow LAN)"
        fatal "操作已中止。"
    fi

    # 5. 注入当前环境
    export http_proxy="$EFFECTIVE_HTTP_PROXY"
    export https_proxy="$EFFECTIVE_HTTP_PROXY"
    export all_proxy="$EFFECTIVE_HTTP_PROXY"
    return 0 
}

configure_socks_bridge() {
    local socks_url="$1"
    local arch=$(uname -m)
    local gost_url=""
    
    case $arch in
        x86_64)  gost_url="https://github.com/ginuerzh/gost/releases/download/v${GOST_VER}/gost-linux-amd64-${GOST_VER}.gz" ;;
        aarch64) gost_url="https://github.com/ginuerzh/gost/releases/download/v${GOST_VER}/gost-linux-arm64-${GOST_VER}.gz" ;;
        armv7*)  gost_url="https://github.com/ginuerzh/gost/releases/download/v${GOST_VER}/gost-linux-armv7-${GOST_VER}.gz" ;;
        *) warn "不支持的架构: $arch"; return 1 ;;
    esac

    if [ ! -f "$GOST_BIN" ]; then
        info "下载协议转换工具 (gost)..."
        # 这里使用 socks_url (即 socks5://ip:port) 直接下载，curl 支持
        curl -L --connect-timeout 10 --retry 2 --proxy "$socks_url" "$gost_url" -o "$WORK_DIR/gost.gz" || \
        curl -L --connect-timeout 10 --retry 2 "$gost_url" -o "$WORK_DIR/gost.gz" || \
        fatal "Gost 下载失败，请确保网络通畅。"
        
        gunzip "$WORK_DIR/gost.gz"
        mv "$WORK_DIR/gost" "$GOST_BIN"
        chmod +x "$GOST_BIN"
    fi

    cat > "$BRIDGE_SERVICE_FILE" <<EOF
[Unit]
Description=Docker SOCKS-to-HTTP Bridge
After=network.target

[Service]
Type=simple
ExecStart=$GOST_BIN -L http://127.0.0.1:$BRIDGE_PORT -F $socks_url
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now docker-socks-bridge >/dev/null 2>&1
    sleep 2
    if command -v ss &>/dev/null; then
        if ! ss -tuln | grep -q ":$BRIDGE_PORT"; then return 1; fi
    fi
    return 0
}

# --- 核心 2: 配置写入 ---

setup_systemd_proxy() {
    [ -z "$EFFECTIVE_HTTP_PROXY" ] && return
    info "写入 Systemd 代理配置..."
    ensure_dir "$SYSTEMD_PROXY_DIR"
    cat > "$SYSTEMD_PROXY_FILE" <<EOF
[Service]
Environment="HTTP_PROXY=$EFFECTIVE_HTTP_PROXY"
Environment="http_proxy=$EFFECTIVE_HTTP_PROXY"
Environment="HTTPS_PROXY=$EFFECTIVE_HTTP_PROXY"
Environment="https_proxy=$EFFECTIVE_HTTP_PROXY"
Environment="NO_PROXY=localhost,127.0.0.1,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
Environment="no_proxy=localhost,127.0.0.1,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
EOF
    systemctl daemon-reload
}

setup_client_proxy() {
    [ -z "$EFFECTIVE_HTTP_PROXY" ] && return
    info "写入 Client 代理配置..."
    ensure_dir "$(dirname "$CLIENT_CONFIG_FILE")"
    
    # 这里的 EFFECTIVE_HTTP_PROXY 可能是直连的 HTTP，也可能是本地的 Bridge HTTP
    # 对 Client 来说都一样
    local proxy_val="$EFFECTIVE_HTTP_PROXY"

    python3 -c "
import json, os
path = '$CLIENT_CONFIG_FILE'
proxy = '$proxy_val'
data = {}
if os.path.exists(path):
    try:
        with open(path) as f: data = json.load(f)
    except: pass
if 'proxies' not in data: data['proxies'] = {}
if 'default' not in data['proxies']: data['proxies']['default'] = {}
data['proxies']['default']['httpProxy'] = proxy
data['proxies']['default']['httpsProxy'] = proxy
data['proxies']['default']['noProxy'] = 'localhost,127.0.0.1,::1'
with open(path, 'w') as f: json.dump(data, f, indent=4)
"
    chown "$REAL_USER" "$CLIENT_CONFIG_FILE"
}

restart_docker_wait() {
    info "重启 Docker 服务..."
    if command -v systemctl &>/dev/null; then
        systemctl restart docker || warn "Docker 重启命令返回非零值"
        
        info "等待 Docker 守护进程就绪..."
        local max_retries=15
        local count=0
        while [ $count -lt $max_retries ]; do
            if docker info >/dev/null 2>&1; then
                pass "Docker 已重新连接！"
                return 0
            fi
            sleep 1
            ((count++))
            echo -n "."
        done
        echo ""
        warn "Docker 响应超时，后续 Buildx 创建可能会失败。"
    fi
}

# --- 核心 3: 强力构建器 (v8.3 Stable Logic) ---

create_power_builder() {
    [ -z "$EFFECTIVE_HTTP_PROXY" ] && return
    if ! docker info &>/dev/null; then warn "Docker 未运行，跳过 Buildx"; return; fi
    
    local new_builder="proxy-builder"

    echo "------------------------------------------------"
    info "正在清理旧的构建器..."
    
    local existing_builders
    existing_builders=$(docker buildx ls 2>/dev/null | awk '/^[a-zA-Z0-9]/ {print $1}' | grep -vE "^NAME|^default$" | tr -d '*')
    
    if [ -n "$existing_builders" ]; then
        for b in $existing_builders; do
            if [ -n "$b" ]; then
                docker buildx rm "$b" >/dev/null 2>&1
                echo -e "${YELLOW}  - 已删除旧构建器: $b${NC}"
            fi
        done
        pass "旧构建器清理完毕"
    else
        info "没有发现残留的构建器 (default 已保留)，干净！"
    fi

    info "创建强力构建器 '$new_builder'..."
    
    local args=(docker buildx create --use --name "$new_builder" --driver docker-container --driver-opt network=host)
    args+=(--driver-opt "env.http_proxy=$EFFECTIVE_HTTP_PROXY")
    args+=(--driver-opt "env.https_proxy=$EFFECTIVE_HTTP_PROXY")
    args+=(--driver-opt "env.HTTP_PROXY=$EFFECTIVE_HTTP_PROXY")
    args+=(--driver-opt "env.HTTPS_PROXY=$EFFECTIVE_HTTP_PROXY")
    
    local out
    if out=$("${args[@]}" 2>&1); then
        info "正在启动并初始化容器 (Bootstrap)..."
        if ! docker buildx inspect --bootstrap >/dev/null 2>&1; then
            warn "首次启动超时，正在重试..."
            sleep 3
            if ! docker buildx inspect --bootstrap >/dev/null 2>&1; then
                fail "构建器启动失败，详情查看: docker logs buildx_buildkit_proxy-builder0"
                return 1
            fi
        fi
        pass "强力构建器 '$new_builder' 就绪！"
    else
        fail "Buildx 创建命令执行失败。详细错误:"
        echo "$out"
        exit 1
    fi
}

smart_reset() {
    echo -e "${RED}=== 智能重置 (仅撤销网络代理) ===${NC}"
    read -r -p "确认执行? [y/N]: " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || return

    rm -f "$SYSTEMD_PROXY_FILE"
    if [ -f "$CLIENT_CONFIG_FILE" ]; then
        python3 -c "
import json
path = '$CLIENT_CONFIG_FILE'
try:
    with open(path, 'r') as f: data = json.load(f)
    if 'proxies' in data: del data['proxies']
    with open(path, 'w') as f: json.dump(data, f, indent=4)
except: pass
"
    fi
    if systemctl is-active --quiet docker-socks-bridge 2>/dev/null; then
        systemctl stop docker-socks-bridge
        systemctl disable docker-socks-bridge
        rm -f "$BRIDGE_SERVICE_FILE"
        systemctl daemon-reload
    fi
    restart_docker_wait
    if docker buildx ls 2>/dev/null | grep -q "proxy-builder"; then
        docker buildx rm "proxy-builder" >/dev/null 2>&1
    fi
    pass "重置完成。"
}

# --- 主程序 ---

if [ "$EUID" -ne 0 ]; then fatal "请使用 sudo 运行"; fi

clear
echo "================================================"
echo " Docker Proxy Expert v9.0 (Auto-Detect Edition) "
echo "================================================"
echo "1. 全套配置 (Systemd + Client + Buildx)"
echo "2. 仅配置 Daemon (Systemd)"
echo "3. 仅配置 Client (~/.docker/config.json)"
echo "4. 恢复/重置 (撤销代理配置)"
echo "5. 退出"
read -r -p "请选择: " choice

case $choice in
    1)
        if ask_and_verify_proxy; then
            setup_systemd_proxy
            setup_client_proxy
            restart_docker_wait
            create_power_builder
            echo "------------------------------------------------"
            info "当前 Buildx 状态:"
            docker buildx ls
            echo "------------------------------------------------"
            pass "全套代理配置完成！"
        fi
        ;;
    2)
        if ask_and_verify_proxy; then
            setup_systemd_proxy
            restart_docker_wait
            pass "Daemon 代理配置完成！"
        fi
        ;;
    3)
        if ask_and_verify_proxy; then
            setup_client_proxy
            pass "Client 代理配置完成！"
        fi
        ;;
    4)
        smart_reset
        ;;
    *) exit 0 ;;
esac
