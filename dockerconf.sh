#!/bin/bash
set -u
set -o pipefail

# ============================================================
#  Docker Ultimate Setup v4.3 (Zero-Side-Effect)
# ============================================================

# --- 前置环境检查 ---
if [ -z "${BASH_VERSINFO:-}" ] || (( BASH_VERSINFO[0] < 4 )); then
    echo "Error: 本脚本需要 Bash >= 4.0。"
    exit 1
fi

# --- 配置策略 ---
: "${IMG_BINFMT:=tonistiigi/binfmt:latest}"
: "${IMG_BUILDKIT:=moby/buildkit:latest}"
: "${TEST_URL:=https://github.com}"
: "${MAX_JOBS:=10}"

# --- 侦测真实用户 ---
CURRENT_USER=$(id -un 2>/dev/null || echo "root")
REAL_USER="${SUDO_USER:-$CURRENT_USER}"

if [ "$REAL_USER" = "root" ]; then
    REAL_HOME="/root"
else
    if command -v getent &>/dev/null; then
        REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
    fi
    [ -z "${REAL_HOME:-}" ] && REAL_HOME="/home/$REAL_USER"
fi

# --- 全局变量 ---
VALID_MIRRORS=()
declare -A MAP_URL=()

BUILDER_NAME="universal-builder"
DAEMON_FILE="/etc/docker/daemon.json"
SYSTEMD_PROXY_DIR="/etc/systemd/system/docker.service.d"
SYSTEMD_PROXY_FILE="$SYSTEMD_PROXY_DIR/http-proxy.conf"
CLIENT_CONFIG_FILE="$REAL_HOME/.docker/config.json"
BACKUP_ROOT="/etc/docker/backup_configs"
SOURCE_URL="https://status.daocloud.io/status/docker"
RESTART_NEEDED=false

# --- 颜色定义 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- 临时工作区 ---
WORK_DIR=$(mktemp -d) || { echo -e "${RED}FATAL: mktemp failed${NC}"; exit 1; }
trap cleanup EXIT INT TERM

cleanup() {
    local dir="${WORK_DIR:-}"
    if [ -n "$dir" ] && [ -d "$dir" ]; then rm -rf "$dir"; fi
}

# --- 辅助函数 ---
info() { echo -e "${CYAN}[INFO]${NC} $1"; }
pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; }
exec_log() { echo -e "${BLUE}[EXEC]${NC} $1"; }
fatal() { echo -e "${RED}[FATAL]${NC} $1"; exit 1; }

check_path_safety() {
    local path="$1"
    local current="$path"
    
    if [ ! -e "$current" ] && [ ! -L "$current" ]; then
        current=$(dirname "$current")
    fi

    while [[ "$current" != "/" && "$current" != "." ]]; do
        if [ -L "$current" ]; then
            fatal "Security Violation: Symlink detected at '$current' (part of '$path')"
        fi
        current=$(dirname "$current")
    done
}

assert_regular_file() {
    local p="$1"
    if [ -e "$p" ] && [ ! -f "$p" ]; then
        fatal "Target exists but is not a regular file: $p"
    fi
}

ensure_dir_safe() {
    local dir="$1"
    check_path_safety "$dir"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" || fatal "Failed to create directory: $dir"
        check_path_safety "$dir"
    fi
}

get_docker_host_ip() {
    local gw=""
    if command -v docker &>/dev/null && docker info &>/dev/null; then
        gw=$(docker network inspect bridge --format='{{range .IPAM.Config}}{{.Gateway}}{{end}}' 2>/dev/null)
    fi
    if [ -z "$gw" ] && command -v getent &>/dev/null; then
        gw=$(getent hosts host.docker.internal | awk '{print $1}')
    fi
    if [ -z "$gw" ]; then gw="172.17.0.1"; fi
    echo "$gw"
}

replace_localhost() {
    local url="$1"
    local new_host="$2"
    
    if [[ "$url" == *"["* ]] || [[ "$url" == *"]"* ]]; then echo "$url"; return; fi
    local at_count="${url//[^@]}"
    if [ "${#at_count}" -gt 1 ]; then echo "$url"; return; fi

    local scheme=""
    local remainder="$url"
    
    if [[ "$url" =~ ^[a-zA-Z0-9+.-]+:// ]]; then
        scheme="${url%%://*}://"
        remainder="${url#*://}"
    fi
    
    local userinfo=""
    if [[ "$remainder" == *"@"* ]]; then
        userinfo="${remainder%%@*}@"
        remainder="${remainder#*@}"
    fi
    
    local host_part="${remainder%%[:/]*}"
    
    if [[ "$host_part" == "localhost" || "$host_part" == "127.0.0.1" ]]; then
        local tail="${remainder#$host_part}"
        echo "${scheme}${userinfo}${new_host}${tail}"
    else
        echo "$url"
    fi
}

reload_systemd() {
    if command -v systemctl &>/dev/null; then
        exec_log "systemctl daemon-reload"
        systemctl daemon-reload || warn "Systemd reload failed"
    fi
}

restart_docker() {
    if command -v systemctl &>/dev/null; then
        exec_log "systemctl restart docker"
        systemctl restart docker || fatal "Docker 重启失败"
        pass "Docker 服务已重启"
    else
        warn "请手动重启 Docker 以生效配置。"
    fi
}

request_restart_docker() { RESTART_NEEDED=true; }

apply_restart() {
    if $RESTART_NEEDED; then
        reload_systemd
        restart_docker
        RESTART_NEEDED=false
    fi
}

print_config() {
    echo -e "${BLUE}=== Current Configuration ===${NC}"
    echo "  User:           $REAL_USER ($REAL_HOME)"
    echo "  Binfmt:         $IMG_BINFMT"
    echo "  Daemon Config:  $DAEMON_FILE"
    echo "  Systemd Proxy:  $SYSTEMD_PROXY_FILE"
    echo "  Client Config:  $CLIENT_CONFIG_FILE"
    echo -e "${BLUE}=============================${NC}"
}

warn_latest_risk() {
    if [[ "$IMG_BINFMT" == *":latest"* ]] || [[ "$IMG_BUILDKIT" == *":latest"* ]]; then
        echo -e "${YELLOW}[SECURITY] 使用 'latest' 标签。建议锁定 Digest。${NC}"
        if [ -t 1 ]; then sleep 1; fi
    fi
}

check_deps() {
    info "检查依赖..."
    for cmd in curl grep sort awk sed cut head wc mktemp install; do
        if ! command -v $cmd &> /dev/null; then fatal "缺少依赖: $cmd"; fi
    done
    if ! command -v diff &> /dev/null; then warn "未检测到 'diff'"; fi
    
    if ! [[ "$MAX_JOBS" =~ ^[1-9][0-9]*$ ]] || [ "$MAX_JOBS" -gt 100 ]; then
        fatal "MAX_JOBS 错误 (1-100)。"
    fi

    if command -v docker &> /dev/null; then
        if ! docker info &> /dev/null; then warn "Docker 未运行，将尝试修复配置。"; fi
    else
        fatal "未找到 docker 命令。"
    fi
}

backup_file() {
    local target="$1"
    if [ ! -f "$target" ]; then return; fi
    check_path_safety "$target"
    assert_regular_file "$target"

    local timestamp
    timestamp=$(date +%F_%H-%M-%S)
    local user_suffix=""
    if [[ "$target" == "$CLIENT_CONFIG_FILE" ]]; then user_suffix=".${REAL_USER}"; fi
    local backup_path="${BACKUP_ROOT}/$(basename "$target")${user_suffix}.${timestamp}.bak"
    
    ensure_dir_safe "$BACKUP_ROOT"
    chmod 700 "$BACKUP_ROOT"
    chown root:root "$BACKUP_ROOT"

    exec_log "Backup: $target -> $backup_path"
    cp "$target" "$backup_path" || fatal "备份失败。"
    
    if [[ "$target" == *".json" ]] || [[ "$target" == *".conf" ]]; then
        chmod 600 "$backup_path"
    fi
    pass "备份完成"
}

get_fastest_mirrors() {
    echo "------------------------------------------------"
    info "获取镜像源..."
    if ! docker info &>/dev/null; then
        warn "Docker 未运行，跳过测速。"
        mapfile -t candidates <<< "https://docker.m.daocloud.io
https://dockerproxy.com
https://mirror.baidubce.com
https://registry-1.docker.io"
        VALID_MIRRORS=("${candidates[@]}")
        return
    fi

    MAP_URL=()
    local source_host
    source_host=$(echo "$SOURCE_URL" | awk -F/ '{print $3}')
    local raw_urls=""
    local html_content=""
    local curl_rc=0
    
    html_content=$(curl -sL --connect-timeout 5 --max-time 10 "$SOURCE_URL") || curl_rc=$?

    if [ "$curl_rc" -eq 0 ] && [ -n "$html_content" ]; then
        raw_urls=$(printf "%s" "$html_content" \
          | grep -oE 'https://[^"'\''<> ]+' \
          | sed -E 's#(https://[^/]+).*#\1#' \
          | grep -vE "^https://$source_host$" \
          | grep -vE 'github\.com' \
          | grep -E '^https://[a-zA-Z0-9.-]+(:[0-9]+)?$' \
          | sort -u || true)
    else
        warn "源列表获取失败 (rc: $curl_rc)，使用保底列表。"
    fi

    if [ -z "$raw_urls" ]; then
        mapfile -t candidates <<< "https://docker.m.daocloud.io
https://dockerproxy.com
https://mirror.baidubce.com
https://registry-1.docker.io"
    else
        mapfile -t candidates <<< "$raw_urls"
        candidates+=("https://registry-1.docker.io")
    fi
    
    # Fix: 镜像源去重
    mapfile -t candidates < <(printf "%s\n" "${candidates[@]}" | sort -u)
    
    pass "解析到 ${#candidates[@]} 个在线源 (已去重)"

    info "测速 (Max Jobs: $MAX_JOBS)..."
    local idx=0
    local running=0
    local use_wait_n=false
    if [[ ${BASH_VERSINFO[0]} -ge 5 ]] || { [[ ${BASH_VERSINFO[0]} -eq 4 ]] && [[ ${BASH_VERSINFO[1]} -ge 3 ]]; }; then use_wait_n=true; fi

    for url in "${candidates[@]}"; do
        url=${url%/}
        ((idx++))
        local job_id=$idx
        (
            res=$(curl -sL -o /dev/null -w "%{http_code}:%{time_total}" --connect-timeout 3 --max-time 5 --retry 1 "$url/v2/")
            code=$(echo "$res" | cut -d':' -f1)
            time=$(echo "$res" | cut -d':' -f2)
            if [[ "$code" =~ ^(200|30[12]|401)$ ]]; then
                echo "$url|$time" > "$WORK_DIR/res.$job_id"
                echo -ne "${GREEN}.${NC}" >&2 
            else
                echo -ne "${RED}.${NC}" >&2
            fi
        ) &
        if $use_wait_n; then
            ((running++))
            if (( running >= MAX_JOBS )); then wait -n; ((running--)); fi
        else
            while [ "$(jobs -r | wc -l)" -ge "$MAX_JOBS" ]; do sleep 0.1; done
        fi
    done
    wait
    echo "" 

    cat "$WORK_DIR"/res.* 2>/dev/null > "$WORK_DIR/merged.txt" || true
    if [ ! -s "$WORK_DIR/merged.txt" ]; then fail "所有镜像源不可用。"; VALID_MIRRORS=(); return; fi

    sort -t'|' -k2 -n "$WORK_DIR/merged.txt" > "$WORK_DIR/sorted.txt"
    echo "------------------------------------------------"
    printf "%-4s %-40s %-10s\n" "Rank" "Mirror URL" "Latency"
    echo "------------------------------------------------"
    local rank=1
    while IFS='|' read -r murl mtime; do
        printf "%-4s %-40s ${GREEN}%.4fs${NC}\n" "[$rank]" "$murl" "$mtime"
        MAP_URL[$rank]=$murl
        ((rank++))
    done < "$WORK_DIR/sorted.txt"

    echo "------------------------------------------------"
    local selection=""
    read -r -p "序号 (默认 1): " selection || selection=""
    VALID_MIRRORS=()
    if [ -z "$selection" ]; then
        if [ -n "${MAP_URL[1]:-}" ]; then VALID_MIRRORS+=("${MAP_URL[1]}"); fi
    else
        for s in $selection; do
            if [[ "$s" =~ ^[0-9]+$ ]] && [ -n "${MAP_URL[$s]:-}" ]; then 
                VALID_MIRRORS+=("${MAP_URL[$s]}")
            fi
        done
    fi
}

merge_daemon_config() {
    [ ${#VALID_MIRRORS[@]} -eq 0 ] && return
    echo "------------------------------------------------"
    info "配置 Daemon 镜像源"
    
    # Fix: 移除提前创建逻辑，避免副作用
    if [ -f "$DAEMON_FILE" ]; then
        check_path_safety "$DAEMON_FILE"
        assert_regular_file "$DAEMON_FILE"
        backup_file "$DAEMON_FILE"
    fi

    local mirrors_json=""
    for m in "${VALID_MIRRORS[@]}"; do mirrors_json+="\"$m\","; done
    mirrors_json=${mirrors_json%,}
    
    ensure_dir_safe "$(dirname "$DAEMON_FILE")"
    local tmp_json
    tmp_json=$(mktemp -p "$(dirname "$DAEMON_FILE")" .daemon.json.tmp.XXXXXX)
    
    # 设置权限
    if [ -f "$DAEMON_FILE" ]; then
        chmod --reference="$DAEMON_FILE" "$tmp_json" 2>/dev/null || chmod 644 "$tmp_json"
        chown --reference="$DAEMON_FILE" "$tmp_json" 2>/dev/null || true
    else
        chmod 644 "$tmp_json"
    fi

    local success=false
    
    if command -v python3 &>/dev/null; then
        exec_log "Using Python3..."
        # Fix: 如果 DAEMON_FILE 不存在，传递 /dev/null
        local src_arg="$DAEMON_FILE"
        if [ ! -f "$DAEMON_FILE" ]; then src_arg="/dev/null"; fi
        
        if python3 - "$src_arg" "$tmp_json" "$mirrors_json" <<'EOF'
import json, sys, os
src, dst, mirrors_str = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    with open(src, 'r') as f:
        # 如果文件为空或不存在(如/dev/null)，初始化空字典
        content = f.read().strip()
        data = json.loads(content) if content else {}
except Exception as e:
    print(f"Error: JSON Load Failed: {e}", file=sys.stderr)
    sys.exit(1) # Fail fast

try:
    new_mirrors = json.loads('[' + mirrors_str + ']') if mirrors_str.strip() else []
except: new_mirrors = []
data['registry-mirrors'] = new_mirrors
if 'log-driver' not in data:
    data['log-driver'] = 'json-file'
    data['log-opts'] = {'max-size': '100m'}
with open(dst, 'w') as f: json.dump(data, f, indent=4)
EOF
        then success=true; fi

    elif command -v jq &>/dev/null; then
        exec_log "Using jq..."
        if [ -f "$DAEMON_FILE" ]; then
             if ! jq . "$DAEMON_FILE" >/dev/null 2>&1; then
                 warn "Daemon JSON 格式错误，无法合并。"
             else
                 if jq --argjson new "[$mirrors_json]" \
                    '.["registry-mirrors"]=$new | (if has("log-driver") then . else . + {"log-driver":"json-file","log-opts":{"max-size":"100m"}} end)' \
                    "$DAEMON_FILE" > "$tmp_json"; then 
                     success=true
                 fi
             fi
        else
             # 文件不存在，初始化新JSON
             if jq -n --argjson new "[$mirrors_json]" \
                '{"registry-mirrors":$new,"log-driver":"json-file","log-opts":{"max-size":"100m"}}' > "$tmp_json"; then
                 success=true
             fi
        fi
    else
        warn "无 jq/python，将覆盖文件！"
        local confirm_ow=""
        read -r -p "确认覆盖? [y/N]: " confirm_ow || confirm_ow=""
        if [[ "$confirm_ow" =~ ^[Yy]$ ]]; then
            cat > "$tmp_json" <<EOF
{ "registry-mirrors": [$mirrors_json], "log-driver": "json-file", "log-opts": { "max-size": "100m" } }
EOF
            success=true
        fi
    fi

    if ! $success; then 
        warn "配置生成失败 (JSON 可能损坏或工具缺失)。"
        local reset_force=""
        read -r -p "重置并覆盖? [y/N]: " reset_force || reset_force=""
        if [[ "$reset_force" =~ ^[Yy]$ ]]; then
             cat > "$tmp_json" <<EOF
{ "registry-mirrors": [$mirrors_json], "log-driver": "json-file", "log-opts": { "max-size": "100m" } }
EOF
             success=true
        else
            rm -f "$tmp_json"; fatal "操作中止。"
        fi
    fi

    echo -e "\n${BLUE}=== [AUDIT] Daemon Config Preview ===${NC}"
    if [ -f "$DAEMON_FILE" ] && command -v diff &>/dev/null; then 
        diff -u "$DAEMON_FILE" "$tmp_json" || true
    else 
        cat "$tmp_json"
    fi
    echo -e "${BLUE}=====================================${NC}"
    
    local confirm=""
    read -r -p "确认写入并计划重启 Docker? [y/N]: " confirm || confirm=""
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then rm -f "$tmp_json"; return; fi

    # Fix: 写入前再次检查路径安全
    if [ -f "$DAEMON_FILE" ]; then check_path_safety "$DAEMON_FILE"; fi
    exec_log "mv $tmp_json -> $DAEMON_FILE"
    mv "$tmp_json" "$DAEMON_FILE"
    chmod 644 "$DAEMON_FILE"
    chown root:root "$DAEMON_FILE"
    request_restart_docker
}

setup_daemon_proxy() {
    echo "------------------------------------------------"
    info "配置 Daemon 代理 (Systemd)"
    if ! command -v systemctl &>/dev/null; then warn "无 systemd，跳过。"; return; fi

    local def_proxy="${HTTP_PROXY:-${http_proxy:-}}"
    local input_proxy=""
    
    local prompt_msg="HTTP 代理"
    if [ -n "$def_proxy" ]; then
        prompt_msg+=" (回车使用环境默认: $def_proxy)"
    else
        prompt_msg+=" (回车跳过/不配置)"
    fi
    
    read -r -p "$prompt_msg: " input_proxy || input_proxy=""
    local final_proxy="${input_proxy:-$def_proxy}"

    if [[ -n "$final_proxy" && "$final_proxy" != *"://"* ]]; then
        final_proxy="http://$final_proxy"
    fi

    if [ -z "$final_proxy" ]; then return; fi
    if [[ "$final_proxy" == *'"'* || "$final_proxy" == *$'\n'* || "$final_proxy" == *$'\r'* ]]; then
        fatal "非法字符检测。"
    fi
    if [[ "$final_proxy" == *'\'* ]]; then fatal "代理包含反斜杠，拒绝写入。"; fi
    if [[ "$final_proxy" == socks* ]]; then
        echo -e "${RED}[WARNING] Docker Daemon 不支持 SOCKS!${NC}"; return; 
    fi

    ensure_dir_safe "$SYSTEMD_PROXY_DIR"
    # 仅当文件存在时检查
    if [ -e "$SYSTEMD_PROXY_FILE" ]; then
        check_path_safety "$SYSTEMD_PROXY_FILE"
        assert_regular_file "$SYSTEMD_PROXY_FILE"
    fi

    local tmp_conf
    tmp_conf=$(mktemp)
    
    local no_proxy_val="localhost,127.0.0.1,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,.svc,.cluster.local"
    local safe_proxy=${final_proxy//%/%%}

    cat > "$tmp_conf" <<EOF
[Service]
Environment="HTTP_PROXY=$safe_proxy"
Environment="http_proxy=$safe_proxy"
Environment="HTTPS_PROXY=$safe_proxy"
Environment="https_proxy=$safe_proxy"
Environment="NO_PROXY=$no_proxy_val"
Environment="no_proxy=$no_proxy_val"
EOF

    echo -e "\n${BLUE}=== [AUDIT] Systemd Proxy Config ===${NC}"
    cat "$tmp_conf"
    echo -e "${BLUE}====================================${NC}"

    local confirm=""
    read -r -p "确认写入? [y/N]: " confirm || confirm=""
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        backup_file "$SYSTEMD_PROXY_FILE"
        mv "$tmp_conf" "$SYSTEMD_PROXY_FILE"
        chmod 600 "$SYSTEMD_PROXY_FILE" 
        chown root:root "$SYSTEMD_PROXY_FILE" 
        request_restart_docker
    else
        rm -f "$tmp_conf"
    fi
}

setup_client_proxy() {
    echo "------------------------------------------------"
    info "配置 User Client 代理"
    
    local def_proxy="${HTTP_PROXY:-${http_proxy:-}}"
    local input_proxy=""
    
    local prompt_msg="代理"
    if [ -n "$def_proxy" ]; then
        prompt_msg+=" (回车使用环境默认: $def_proxy)"
    else
        prompt_msg+=" (回车跳过/不配置)"
    fi
    
    read -r -p "$prompt_msg: " input_proxy || input_proxy=""
    local final_proxy="${input_proxy:-$def_proxy}"

    if [[ -n "$final_proxy" && "$final_proxy" != *"://"* ]]; then
        final_proxy="http://$final_proxy"
    fi

    if [ -z "$final_proxy" ]; then return; fi
    if [[ "$final_proxy" == *'"'* || "$final_proxy" == *$'\n'* ]]; then fatal "非法字符。"; fi
    
    if [[ "$final_proxy" == *"127.0.0.1"* ]] || [[ "$final_proxy" == *"localhost"* ]]; then
        local host_ip
        host_ip=$(get_docker_host_ip)
        if [ -n "$host_ip" ]; then
            echo -e "${YELLOW}[WARN] 检测到 localhost 代理。${NC}"
            echo -e "${YELLOW}建议替换为宿主 IP: ${GREEN}$host_ip${NC}"
            local auto_fix=""
            read -r -p "自动替换? [Y/n]: " auto_fix || auto_fix=""
            if [[ ! "$auto_fix" =~ ^[Nn]$ ]]; then
                final_proxy=$(replace_localhost "$final_proxy" "$host_ip")
                pass "已修正为: $final_proxy"
            fi
        else
            warn "未检测到 Docker 网关 IP。"
        fi
    fi

    local docker_conf_dir="$REAL_HOME/.docker"
    ensure_dir_safe "$docker_conf_dir"
    chown "$REAL_USER" "$docker_conf_dir"
    
    local tmp_conf
    tmp_conf=$(mktemp)
    
    if [ -f "$CLIENT_CONFIG_FILE" ]; then
        check_path_safety "$CLIENT_CONFIG_FILE"
        assert_regular_file "$CLIENT_CONFIG_FILE"
        backup_file "$CLIENT_CONFIG_FILE"
    fi

    local no_proxy_val="localhost,127.0.0.1,::1"
    local success=false
    
    local source_file="$CLIENT_CONFIG_FILE"
    if [ ! -f "$CLIENT_CONFIG_FILE" ]; then source_file="/dev/null"; fi

    if command -v python3 &>/dev/null; then
         if python3 - "$source_file" "$tmp_conf" "$final_proxy" "$no_proxy_val" <<'EOF'
import json, sys, os
src, dst, proxy, noproxy = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
data = {}
try:
    with open(src, 'r') as f:
        c = f.read().strip()
        data = json.loads(c) if c else {}
except Exception: 
    sys.exit(1)

if 'proxies' not in data: data['proxies'] = {}
if 'default' not in data['proxies']: data['proxies']['default'] = {}
p = data['proxies']['default']
p['httpProxy'] = proxy
p['httpsProxy'] = proxy
p['ftpProxy'] = proxy
p['noProxy'] = noproxy
with open(dst, 'w') as f: json.dump(data, f, indent=4)
EOF
        then success=true; fi

    elif command -v jq &>/dev/null; then
        if [ -f "$CLIENT_CONFIG_FILE" ]; then
            if jq . "$CLIENT_CONFIG_FILE" >/dev/null 2>&1; then
                if jq --arg p "$final_proxy" --arg np "$no_proxy_val" \
                   '.proxies.default.httpProxy=$p | .proxies.default.httpsProxy=$p | .proxies.default.noProxy=$np' \
                   "$CLIENT_CONFIG_FILE" > "$tmp_conf"; then
                   success=true
                fi
            fi
        else
            if jq -n --arg p "$final_proxy" --arg np "$no_proxy_val" \
               '{proxies:{default:{httpProxy:$p, httpsProxy:$p, noProxy:$np}}}' > "$tmp_conf"; then
               success=true
            fi
        fi
    else
        warn "无 jq/python，跳过 Client 配置。"
    fi

    if ! $success; then 
        warn "Client Config 生成失败 (JSON 损坏)。"
        local reset_cli=""
        read -r -p "强制重置? [y/N] " reset_cli || reset_cli=""
        if [[ "$reset_cli" =~ ^[Yy]$ ]]; then
             cat > "$tmp_conf" <<EOF
{ "proxies": { "default": { "httpProxy": "$final_proxy", "httpsProxy": "$final_proxy", "noProxy": "$no_proxy_val" } } }
EOF
             success=true
        else
             rm -f "$tmp_conf"; fail "操作中止。"; return;
        fi
    fi

    echo -e "\n${BLUE}=== [AUDIT] Client Config Preview ===${NC}"
    cat "$tmp_conf"
    echo -e "${BLUE}=====================================${NC}"

    local confirm=""
    read -r -p "确认更新 $REAL_USER 的配置? [y/N]: " confirm || confirm=""
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        if [ -f "$CLIENT_CONFIG_FILE" ]; then check_path_safety "$CLIENT_CONFIG_FILE"; fi
        mv "$tmp_conf" "$CLIENT_CONFIG_FILE"
        chown "$REAL_USER" "$CLIENT_CONFIG_FILE"
        chmod 600 "$CLIENT_CONFIG_FILE"
        pass "Client 代理已配置"
    else
        rm -f "$tmp_conf"
    fi
}

create_buildx() {
    if ! docker info &>/dev/null; then
        warn "Docker Daemon 不可用，跳过 Buildx 配置。"
        return
    fi
    
    if ! docker buildx version >/dev/null 2>&1; then
        warn "Docker Buildx 插件不可用。跳过 Buildx 配置。"
        return
    fi
    echo "------------------------------------------------"
    info "创建 Buildx 环境"
    
    local mirrors_toml=""
    if [ ${#VALID_MIRRORS[@]} -gt 0 ]; then
        for m in "${VALID_MIRRORS[@]}"; do mirrors_toml+="\"$m\","; done
        mirrors_toml=${mirrors_toml%,}
    fi

    local toml_file="$WORK_DIR/buildkitd.toml"
    cat > "$toml_file" <<EOF
debug = true
[registry."docker.io"]
  mirrors = [$mirrors_toml]
EOF

    local proxy_args=()
    local enable_proxy=""
    
    local prompt_msg="Buildx 内部代理"
    local def_proxy="${HTTP_PROXY:-${http_proxy:-}}"
    if [ -n "$def_proxy" ]; then
        prompt_msg+=" (回车使用环境默认: $def_proxy)"
    else
        prompt_msg+=" (回车跳过/不配置)"
    fi
    
    read -r -p "$prompt_msg: " enable_proxy || enable_proxy=""
    
    local final_proxy=""
    
    if [ -z "$enable_proxy" ] && [ -n "$def_proxy" ]; then
        final_proxy="$def_proxy"
    elif [[ "$enable_proxy" =~ ^[Yy]$ ]]; then
        read -r -p "输入代理: " final_proxy || final_proxy=""
    elif [ -n "$enable_proxy" ] && [[ ! "$enable_proxy" =~ ^[Nn]$ ]]; then
        final_proxy="$enable_proxy"
    fi

    if [ -n "$final_proxy" ]; then
         if [[ "$final_proxy" == *'"'* || "$final_proxy" == *$'\n'* ]]; then fatal "非法字符"; fi
         local np="localhost,127.0.0.1,::1"
         proxy_args+=(--driver-opt "env.http_proxy=$final_proxy")
         proxy_args+=(--driver-opt "env.https_proxy=$final_proxy")
         proxy_args+=(--driver-opt "env.HTTP_PROXY=$final_proxy")
         proxy_args+=(--driver-opt "env.HTTPS_PROXY=$final_proxy")
         proxy_args+=(--driver-opt "env.no_proxy=$np")
         proxy_args+=(--driver-opt "env.NO_PROXY=$np")
         proxy_args+=(--driver-opt "env.all_proxy=$final_proxy")
         proxy_args+=(--driver-opt "env.ALL_PROXY=$final_proxy")
    fi

    if docker buildx ls | grep -Fq "$BUILDER_NAME"; then docker buildx rm "$BUILDER_NAME" >/dev/null 2>&1; fi
    local use_host=""
    read -r -p "启用 Host 网络模式? [Y/n]: " use_host || use_host=""
    
    local cmd_args=(docker buildx create --use --name "$BUILDER_NAME" \
       --driver docker-container \
       --driver-opt "image=$IMG_BUILDKIT" \
       --config "$toml_file" \
       --platform linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v6)
    
    if [ ${#proxy_args[@]} -gt 0 ]; then cmd_args+=("${proxy_args[@]}"); fi
    if [[ ! "$use_host" =~ ^[Nn]$ ]]; then cmd_args+=(--driver-opt network=host --buildkitd-flags "--allow-insecure-entitlement network.host"); fi

    exec_log "Creating builder..."
    "${cmd_args[@]}" || fatal "Buildx Failed"
    docker buildx inspect --bootstrap || fatal "Bootstrap Failed"
    pass "Buildx Ready"
}

# ------------------------------------------------------------
# 主程序
# ------------------------------------------------------------
if [ "$EUID" -ne 0 ]; then fatal "请使用 sudo 运行"; fi
check_deps
warn_latest_risk

command -v clear &>/dev/null && clear || true
print_config

echo "================================================"
echo " Docker Ultimate Setup v4.3 (Zero-Side-Effect)  "
echo "================================================"
echo "1. 全套配置 (Daemon源 + Systemd代理 + Client代理 + Buildx)"
echo "2. 仅配置 Daemon源 + Systemd代理 + Buildx"
echo "3. 仅配置 User Client 代理 (docker run 生效)"
echo "4. 恢复环境"
echo "5. 退出"
choice=""
read -r -p "选择: " choice || choice=""

case $choice in
    1|2)
        get_fastest_mirrors
        
        merge_daemon_config # 镜像源
        setup_daemon_proxy  # Systemd 代理
        
        apply_restart
        
        if [ "$choice" == "1" ]; then setup_client_proxy; fi 

        info "安装 QEMU..."
        if docker info &>/dev/null; then
             docker run --privileged --rm "$IMG_BINFMT" --install all >/dev/null 2>&1 || warn "QEMU 安装失败 (网络问题?)"
        fi
        
        create_buildx
        ;;
    3)
        setup_client_proxy
        ;;
    4)
        warn "开始恢复..."
        if docker info &>/dev/null; then docker buildx rm "$BUILDER_NAME" 2>/dev/null; fi
        
        lb=$(ls -t "$BACKUP_ROOT"/daemon.json.*.bak 2>/dev/null | head -n 1)
        if [ -n "$lb" ]; then 
            r=""
            read -r -p "恢复 Daemon JSON ($lb)? [y/N] " r || r=""
            if [[ "$r" =~ ^[Yy]$ ]]; then 
                check_path_safety "$DAEMON_FILE"
                cp "$lb" "$DAEMON_FILE" || fatal "恢复失败"
                chmod 644 "$DAEMON_FILE"
                chown root:root "$DAEMON_FILE"
                request_restart_docker
            fi
        fi
        
        lp=$(ls -t "$BACKUP_ROOT"/http-proxy.conf.*.bak 2>/dev/null | head -n 1)
        if [ -n "$lp" ]; then
             r=""
             read -r -p "恢复 Systemd Proxy ($lp)? [y/N] " r || r=""
             if [[ "$r" =~ ^[Yy]$ ]]; then 
                 check_path_safety "$SYSTEMD_PROXY_FILE"
                 cp "$lp" "$SYSTEMD_PROXY_FILE" || fatal "恢复失败"
                 chmod 600 "$SYSTEMD_PROXY_FILE"
                 chown root:root "$SYSTEMD_PROXY_FILE"
                 reload_systemd; request_restart_docker
             fi
        fi
        
        apply_restart

        lc=$(ls -t "$BACKUP_ROOT"/config.json.*${REAL_USER}*.bak 2>/dev/null | head -n 1)
        if [ -n "$lc" ]; then
             r=""
             read -r -p "恢复 Client Config ($lc)? [y/N] " r || r=""
             if [[ "$r" =~ ^[Yy]$ ]]; then 
                 check_path_safety "$CLIENT_CONFIG_FILE"
                 cp "$lc" "$CLIENT_CONFIG_FILE" || fatal "恢复失败"
                 chmod 600 "$CLIENT_CONFIG_FILE"
                 chown "$REAL_USER" "$CLIENT_CONFIG_FILE"
                 pass "Client Config Restored"
             fi
        fi
        ;;
    *) exit 0 ;;
esac

echo -e "\n${GREEN}Operations Completed.${NC}"
