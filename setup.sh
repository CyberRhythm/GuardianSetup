#!/usr/bin/env bash
# ============================================================
#  SERVER SETUP SCRIPT
#  Author: Personal Server Setup
#  Version: 1.0.0
# ============================================================

set -euo pipefail

# ─────────────────────────────────────────────────────────────
# COLORS & FORMATTING
# ─────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# ─────────────────────────────────────────────────────────────
# PATHS
# ─────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
CONFIG_DIR="$SCRIPT_DIR/config"
MODULES_DIR="$SCRIPT_DIR/modules"
LOG_FILE="$LOG_DIR/setup_$(date +%Y%m%d_%H%M%S).log"
WHITELIST_FILE="$CONFIG_DIR/port_whitelist.conf"
STATE_FILE="$CONFIG_DIR/state.conf"

mkdir -p "$LOG_DIR" "$CONFIG_DIR" "$MODULES_DIR"

# ─────────────────────────────────────────────────────────────
# LOGGING
# ─────────────────────────────────────────────────────────────
log()     { echo -e "${GREEN}[OK]${NC} $*"      | tee -a "$LOG_FILE"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"   | tee -a "$LOG_FILE"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"     | tee -a "$LOG_FILE"; }
info()    { echo -e "${BLUE}[INFO]${NC} $*"     | tee -a "$LOG_FILE"; }
section() { echo -e "\n${MAGENTA}${BOLD}══════ $* ══════${NC}\n" | tee -a "$LOG_FILE"; }
step()    { echo -e "${CYAN}  -->  ${NC}$*"     | tee -a "$LOG_FILE"; }

# ─────────────────────────────────────────────────────────────
# ROOT CHECK
# ─────────────────────────────────────────────────────────────
require_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root."
        error "Please run: sudo $0"
        exit 1
    fi
}

# ─────────────────────────────────────────────────────────────
# BANNER
# ─────────────────────────────────────────────────────────────
show_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    cat << 'EOF'
  ╔═══════════════════════════════════════════════════════════╗
  ║          SERVER SETUP & SECURITY MANAGER v1.0             ║
  ╚═══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -e "  ${BLUE}Date:${NC}  $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "  ${BLUE}Host:${NC}  $(hostname)"
    echo -e "  ${BLUE}IP:${NC}    $(hostname -I | awk '{print $1}' 2>/dev/null || echo 'N/A')"
    echo -e "  ${BLUE}Log:${NC}   $LOG_FILE"
    echo ""
}

# ─────────────────────────────────────────────────────────────
# MAIN MENU
# ─────────────────────────────────────────────────────────────
main_menu() {
    while true; do
        echo -e "\n${BOLD}${BLUE}╔══════════════════════════════════════╗${NC}"
        echo -e "${BOLD}${BLUE}║             Main Menu                ║${NC}"
        echo -e "${BOLD}${BLUE}╚══════════════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${GREEN}1)${NC}  Full Setup  (update + security)"
        echo -e "  ${GREEN}2)${NC}  System Update"
        echo -e "  ${GREEN}3)${NC}  Security Settings"
        echo -e "  ${GREEN}4)${NC}  Scan Server  (what is installed?)"
        echo -e "  ${GREEN}5)${NC}  Firewall Manager  (UFW)"
        echo -e "  ${GREEN}6)${NC}  Enable Services"
        echo -e "  ${GREEN}7)${NC}  Disable Services"
        echo -e "  ${GREEN}8)${NC}  Server Status"
        echo -e "  ${GREEN}9)${NC}  View Logs"
        echo -e "  ${RED}0)${NC}  Exit"
        echo ""
        read -rp "$(echo -e "${CYAN}Select:${NC} ")" choice

        case "$choice" in
            1) run_full_setup ;;
            2) run_updates ;;
            3) security_menu ;;
            4) scan_server ;;
            5) firewall_menu ;;
            6) enable_menu ;;
            7) disable_menu ;;
            8) show_status ;;
            9) view_logs ;;
            0) echo -e "\n${GREEN}Goodbye!${NC}\n"; exit 0 ;;
            *) warn "Invalid option." ;;
        esac
    done
}

# ─────────────────────────────────────────────────────────────
# MODULE 1: FULL SETUP
# ─────────────────────────────────────────────────────────────
run_full_setup() {
    section "Full Setup"
    run_updates
    security_hardening
    configure_firewall_smart
    log "Full setup complete."
}

# ─────────────────────────────────────────────────────────────
# MODULE 2: SYSTEM UPDATE
# ─────────────────────────────────────────────────────────────
run_updates() {
    section "System Update"

    local distro
    distro=$(detect_distro)

    case "$distro" in
        ubuntu|debian)
            step "Updating package list..."
            apt-get update -qq 2>&1 | tee -a "$LOG_FILE"
            step "Upgrading packages..."
            DEBIAN_FRONTEND=noninteractive apt-get upgrade -y 2>&1 | tee -a "$LOG_FILE"
            step "Distribution upgrade..."
            DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y 2>&1 | tee -a "$LOG_FILE"
            step "Removing unused packages..."
            apt-get autoremove -y 2>&1 | tee -a "$LOG_FILE"
            apt-get autoclean 2>&1 | tee -a "$LOG_FILE"
            ;;
        centos|rhel|fedora|rocky|almalinux)
            step "Updating system..."
            if command -v dnf &>/dev/null; then
                dnf upgrade -y 2>&1 | tee -a "$LOG_FILE"
                dnf autoremove -y 2>&1 | tee -a "$LOG_FILE"
            else
                yum update -y 2>&1 | tee -a "$LOG_FILE"
            fi
            ;;
        arch)
            step "Updating Arch..."
            pacman -Syu --noconfirm 2>&1 | tee -a "$LOG_FILE"
            ;;
        *)
            warn "Unknown distro: $distro"
            ;;
    esac

    log "System update complete."
}

# ─────────────────────────────────────────────────────────────
# MODULE 3: SECURITY MENU
# ─────────────────────────────────────────────────────────────
security_menu() {
    while true; do
        echo -e "\n${BOLD}${BLUE}╔══════════════════════════════════════╗${NC}"
        echo -e "${BOLD}${BLUE}║           Security Menu              ║${NC}"
        echo -e "${BOLD}${BLUE}╚══════════════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${GREEN}1)${NC}  Apply all security settings"
        echo -e "  ${GREEN}2)${NC}  Harden SSH"
        echo -e "  ${GREEN}3)${NC}  User management"
        echo -e "  ${GREEN}4)${NC}  Install & configure Fail2Ban"
        echo -e "  ${GREEN}5)${NC}  Install & configure ClamAV"
        echo -e "  ${GREEN}6)${NC}  Install Auditd  (security logging)"
        echo -e "  ${GREEN}7)${NC}  Enable automatic security updates"
        echo -e "  ${GREEN}8)${NC}  Harden kernel  (sysctl)"
        echo -e "  ${RED}0)${NC}  Back"
        echo ""
        read -rp "$(echo -e "${CYAN}Select:${NC} ")" choice

        case "$choice" in
            1) security_hardening ;;
            2) harden_ssh ;;
            3) manage_users ;;
            4) setup_fail2ban ;;
            5) setup_clamav ;;
            6) setup_auditd ;;
            7) setup_unattended_upgrades ;;
            8) harden_kernel ;;
            0) return ;;
            *) warn "Invalid option." ;;
        esac
    done
}

security_hardening() {
    section "Security Hardening"
    harden_ssh
    setup_fail2ban
    harden_kernel
    setup_unattended_upgrades
    log "All security settings applied."
}

harden_ssh() {
    step "Hardening SSH..."
    local sshd_config="/etc/ssh/sshd_config"

    # Backup
    cp "$sshd_config" "${sshd_config}.backup_$(date +%Y%m%d)" 2>/dev/null || true

    declare -A ssh_settings=(
        ["PermitRootLogin"]="no"
        ["PasswordAuthentication"]="yes"
        ["PermitEmptyPasswords"]="no"
        ["X11Forwarding"]="no"
        ["MaxAuthTries"]="3"
        ["LoginGraceTime"]="30"
        ["ClientAliveInterval"]="300"
        ["ClientAliveCountMax"]="2"
        ["Protocol"]="2"
    )

    for key in "${!ssh_settings[@]}"; do
        val="${ssh_settings[$key]}"
        if grep -qE "^#?${key}" "$sshd_config"; then
            sed -i "s|^#\?${key}.*|${key} ${val}|" "$sshd_config"
        else
            echo "${key} ${val}" >> "$sshd_config"
        fi
        step "  SSH: $key = $val"
    done

    if sshd -t 2>/dev/null; then
        systemctl reload sshd 2>/dev/null || systemctl reload ssh 2>/dev/null || true
        log "SSH hardening applied."
    else
        error "SSH config validation failed — restoring backup..."
        cp "${sshd_config}.backup_$(date +%Y%m%d)" "$sshd_config"
    fi
}

setup_fail2ban() {
    step "Installing Fail2Ban..."
    local distro
    distro=$(detect_distro)

    case "$distro" in
        ubuntu|debian)
            apt-get install -y fail2ban 2>&1 | tee -a "$LOG_FILE" ;;
        centos|rhel|rocky|almalinux)
            yum install -y epel-release fail2ban 2>&1 | tee -a "$LOG_FILE" ;;
        fedora)
            dnf install -y fail2ban 2>&1 | tee -a "$LOG_FILE" ;;
    esac

    cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5
ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled = true
port    = ssh
logpath = %(sshd_log)s
maxretry = 3
bantime  = 7200

[nginx-http-auth]
enabled = true

[nginx-botsearch]
enabled = true
EOF

    systemctl enable fail2ban
    systemctl restart fail2ban
    log "Fail2Ban installed and enabled."
}

setup_clamav() {
    step "Installing ClamAV..."
    local distro
    distro=$(detect_distro)

    case "$distro" in
        ubuntu|debian)
            apt-get install -y clamav clamav-daemon 2>&1 | tee -a "$LOG_FILE"
            systemctl stop clamav-freshclam 2>/dev/null || true
            freshclam 2>&1 | tee -a "$LOG_FILE" || true
            systemctl start clamav-freshclam
            systemctl enable clamav-freshclam
            ;;
        centos|rhel|rocky|almalinux|fedora)
            yum install -y clamav clamd 2>&1 | tee -a "$LOG_FILE" || \
            dnf install -y clamav clamd 2>&1 | tee -a "$LOG_FILE"
            freshclam 2>&1 | tee -a "$LOG_FILE" || true
            ;;
    esac

    # Schedule daily scan
    cat > /etc/cron.daily/clamav-scan << 'EOF'
#!/bin/bash
clamscan -r /home /tmp /var/www --log=/var/log/clamav/daily-scan.log --quiet
EOF
    chmod +x /etc/cron.daily/clamav-scan
    log "ClamAV installed. Daily scan scheduled."
}

setup_auditd() {
    step "Installing Auditd..."
    local distro
    distro=$(detect_distro)

    case "$distro" in
        ubuntu|debian)
            apt-get install -y auditd audispd-plugins 2>&1 | tee -a "$LOG_FILE" ;;
        centos|rhel|rocky|almalinux|fedora)
            yum install -y audit 2>&1 | tee -a "$LOG_FILE" ;;
    esac

    cat > /etc/audit/rules.d/server-security.rules << 'EOF'
# Monitor login files
-w /var/log/lastlog -p wa -k login
-w /var/run/faillock -p wa -k login

# Monitor sudoers
-w /etc/sudoers -p wa -k sudoers
-w /etc/sudoers.d/ -p wa -k sudoers

# Monitor SSH config
-w /etc/ssh/sshd_config -p wa -k sshd

# Monitor crontabs
-w /etc/cron.d/ -p wa -k cron
-w /etc/crontab -p wa -k cron
-w /var/spool/cron/ -p wa -k cron

# Monitor user/group changes
-w /etc/group -p wa -k identity
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
EOF

    systemctl enable auditd
    systemctl restart auditd
    log "Auditd installed. Audit rules applied."
}

setup_unattended_upgrades() {
    step "Configuring automatic security updates..."
    local distro
    distro=$(detect_distro)

    case "$distro" in
        ubuntu|debian)
            apt-get install -y unattended-upgrades 2>&1 | tee -a "$LOG_FILE"
            cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
EOF
            dpkg-reconfigure -plow unattended-upgrades 2>/dev/null || true
            ;;
        centos|rhel|rocky|almalinux)
            yum install -y dnf-automatic 2>&1 | tee -a "$LOG_FILE" || true
            sed -i 's/apply_updates = no/apply_updates = yes/' /etc/dnf/automatic.conf 2>/dev/null || true
            systemctl enable --now dnf-automatic.timer 2>/dev/null || true
            ;;
    esac
    log "Automatic security updates enabled."
}

harden_kernel() {
    step "Hardening kernel via sysctl..."

    cat > /etc/sysctl.d/99-security.conf << 'EOF'
# ─── Network Security ───────────────────────────────────────
# Disable IP forwarding (unless this is a router)
net.ipv4.ip_forward = 0

# Disable ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0

# Ignore ICMP broadcast requests
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Ignore bogus ICMP responses
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Enable TCP SYN cookies (SYN flood protection)
net.ipv4.tcp_syncookies = 1

# Enable reverse path filtering
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Disable source routing
net.ipv4.conf.all.accept_source_route = 0

# Log Martian packets
net.ipv4.conf.all.log_martians = 1

# ─── Memory Security ────────────────────────────────────────
# Address Space Layout Randomization (ASLR)
kernel.randomize_va_space = 2

# Restrict core dumps
fs.suid_dumpable = 0

# Restrict dmesg access
kernel.dmesg_restrict = 1

# Restrict ptrace scope
kernel.yama.ptrace_scope = 1
EOF

    sysctl -p /etc/sysctl.d/99-security.conf 2>&1 | tee -a "$LOG_FILE" || true
    log "Kernel hardening applied."
}

manage_users() {
    echo -e "\n${CYAN}User Management${NC}"
    echo "1) Show sudo users"
    echo "2) Show last logins"
    echo "3) Show currently logged-in users"
    echo "0) Back"
    read -rp "Select: " choice
    case "$choice" in
        1)
            echo -e "\n${YELLOW}Users with sudo access:${NC}"
            grep -E '^sudo|^wheel' /etc/group | cut -d: -f4
            ;;
        2)
            echo -e "\n${YELLOW}Last logins:${NC}"
            last -n 20
            ;;
        3)
            echo -e "\n${YELLOW}Currently logged-in users:${NC}"
            who
            ;;
        0) return ;;
    esac
}

# ─────────────────────────────────────────────────────────────
# MODULE 4: SERVER SCAN
# ─────────────────────────────────────────────────────────────
scan_server() {
    section "Server Scan — What is installed?"

    echo -e "\n${BOLD}Installed Services:${NC}\n"

    local services=(
        "nginx:NGINX Web Server"
        "apache2:Apache Web Server"
        "httpd:Apache (RHEL)"
        "mysql:MySQL Database"
        "mariadb:MariaDB Database"
        "postgresql:PostgreSQL Database"
        "mongod:MongoDB"
        "redis-server:Redis"
        "rabbitmq-server:RabbitMQ"
        "docker:Docker"
        "containerd:ContainerD"
        "php-fpm:PHP-FPM"
        "nodejs:Node.js"
        "python3:Python3"
        "ufw:UFW Firewall"
        "firewalld:FirewallD"
        "fail2ban:Fail2Ban"
        "clamav-daemon:ClamAV"
        "auditd:Auditd"
        "cron:Cron"
        "ssh:SSH Server"
        "postfix:Postfix Mail"
        "certbot:Certbot (Let's Encrypt)"
    )

    printf "%-30s %-12s %-12s\n" "Service" "Installed" "Status"
    printf "%-30s %-12s %-12s\n" "──────────────────────────" "─────────" "──────────"

    for entry in "${services[@]}"; do
        local svc="${entry%%:*}"
        local name="${entry#*:}"
        local installed="No"
        local status=""

        if command -v "$svc" &>/dev/null || systemctl list-unit-files "${svc}.service" &>/dev/null 2>&1; then
            installed="Yes"
            if systemctl is-active --quiet "$svc" 2>/dev/null; then
                status="${GREEN}running${NC}"
            elif systemctl is-enabled --quiet "$svc" 2>/dev/null; then
                status="${YELLOW}stopped${NC}"
            else
                status="${RED}disabled${NC}"
            fi
        fi

        if [[ "$installed" == "Yes" ]]; then
            printf "%-30s %-12s " "$name" "$installed"
            echo -e "$status"
        fi
    done

    echo -e "\n${BOLD}Active Ports & Whitelist:${NC}\n"
    scan_ports

    echo -e "\n${BOLD}Disk Usage:${NC}"
    df -h | grep -v tmpfs | grep -v udev

    echo -e "\n${BOLD}Memory:${NC}"
    free -h

    echo -e "\n${BOLD}Top Processes (by CPU):${NC}"
    ps aux --sort=-%cpu | head -11 | awk '{printf "%-20s %-8s %-8s %s\n", $11, $3, $4, $1}'

    log "Server scan complete."
}

scan_ports() {
    local active_ports=()

    echo -e "${YELLOW}Scanning active ports...${NC}"

    if command -v ss &>/dev/null; then
        mapfile -t port_lines < <(ss -tlnup 2>/dev/null | grep LISTEN | awk '{print $4}' | grep -oP ':\K[0-9]+' | sort -un)
    elif command -v netstat &>/dev/null; then
        mapfile -t port_lines < <(netstat -tlnup 2>/dev/null | grep LISTEN | awk '{print $4}' | grep -oP ':\K[0-9]+' | sort -un)
    else
        warn "Neither ss nor netstat found."
        return
    fi

    # Load existing whitelist
    declare -A whitelist
    if [[ -f "$WHITELIST_FILE" ]]; then
        while IFS= read -r line; do
            [[ "$line" =~ ^#|^$ ]] && continue
            whitelist["$line"]=1
        done < "$WHITELIST_FILE"
    fi

    printf "\n%-8s %-20s %-14s %-30s\n" "Port" "Service" "Status" "Action"
    printf "%-8s %-20s %-14s %-30s\n" "────" "──────────────────" "────────────" "────────────────────────────"

    for port in "${port_lines[@]}"; do
        local service_name
        service_name=$(get_service_for_port "$port")
        local wl_status
        local action

        if [[ -v whitelist["$port"] ]]; then
            wl_status="${GREEN}whitelisted${NC}"
            action="OK — approved"
        else
            wl_status="${YELLOW}new${NC}"
            action="Review required"
            active_ports+=("$port")
        fi

        printf "%-8s %-20s " "$port" "$service_name"
        echo -e "$wl_status   $action"
    done

    if [[ ${#active_ports[@]} -gt 0 ]]; then
        echo ""
        warn "New ports detected: ${active_ports[*]}"
        read -rp "$(echo -e "${CYAN}Add all new ports to whitelist? [y/N]:${NC} ")" answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            for port in "${active_ports[@]}"; do
                echo "$port" >> "$WHITELIST_FILE"
                log "Port $port added to whitelist."
            done
        else
            info "You can manage ports individually via the Firewall menu."
        fi
    fi
}

get_service_for_port() {
    local port=$1
    declare -A known_ports=(
        [21]="FTP"          [22]="SSH"          [25]="SMTP"
        [53]="DNS"          [80]="HTTP"          [110]="POP3"
        [143]="IMAP"        [443]="HTTPS"        [465]="SMTP/SSL"
        [587]="SMTP/TLS"    [993]="IMAP/SSL"     [995]="POP3/SSL"
        [3306]="MySQL"      [5432]="PostgreSQL"  [6379]="Redis"
        [8080]="HTTP-Alt"   [8443]="HTTPS-Alt"   [27017]="MongoDB"
        [5672]="RabbitMQ"   [15672]="RabbitMQ-UI" [9200]="Elasticsearch"
        [2375]="Docker"     [2376]="Docker-TLS"  [9000]="PHP-FPM/Portainer"
        [10050]="Zabbix"    [3000]="Grafana/Node" [5900]="VNC"
    )
    echo "${known_ports[$port]:-Unknown}"
}

# ─────────────────────────────────────────────────────────────
# MODULE 5: FIREWALL MENU
# ─────────────────────────────────────────────────────────────
firewall_menu() {
    while true; do
        echo -e "\n${BOLD}${BLUE}╔══════════════════════════════════════╗${NC}"
        echo -e "${BOLD}${BLUE}║          Firewall Menu  (UFW)        ║${NC}"
        echo -e "${BOLD}${BLUE}╚══════════════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${GREEN}1)${NC}  Smart firewall setup  (active ports)"
        echo -e "  ${GREEN}2)${NC}  Open a port"
        echo -e "  ${GREEN}3)${NC}  Close a port"
        echo -e "  ${GREEN}4)${NC}  Show UFW status"
        echo -e "  ${GREEN}5)${NC}  Enable UFW"
        echo -e "  ${GREEN}6)${NC}  Disable UFW"
        echo -e "  ${GREEN}7)${NC}  Manage port whitelist"
        echo -e "  ${RED}0)${NC}  Back"
        echo ""
        read -rp "$(echo -e "${CYAN}Select:${NC} ")" choice

        case "$choice" in
            1) configure_firewall_smart ;;
            2) open_port ;;
            3) close_port ;;
            4) ufw status verbose 2>/dev/null || info "UFW is not installed." ;;
            5) enable_ufw ;;
            6) disable_ufw ;;
            7) manage_whitelist ;;
            0) return ;;
            *) warn "Invalid option." ;;
        esac
    done
}

configure_firewall_smart() {
    section "Smart Firewall Setup"

    if ! command -v ufw &>/dev/null; then
        step "Installing UFW..."
        local distro
        distro=$(detect_distro)
        case "$distro" in
            ubuntu|debian) apt-get install -y ufw 2>&1 | tee -a "$LOG_FILE" ;;
            centos|rhel|rocky|almalinux) yum install -y ufw 2>&1 | tee -a "$LOG_FILE" ;;
        esac
    fi

    local active_ports=()
    if command -v ss &>/dev/null; then
        mapfile -t active_ports < <(ss -tlnup 2>/dev/null | grep LISTEN | awk '{print $4}' | grep -oP ':\K[0-9]+' | sort -un)
    fi

    local whitelist_ports=()
    if [[ -f "$WHITELIST_FILE" ]]; then
        mapfile -t whitelist_ports < <(grep -v '^#' "$WHITELIST_FILE" | grep -v '^$')
    fi

    local all_ports=()
    all_ports=("${active_ports[@]}" "${whitelist_ports[@]}")

    declare -A seen
    local unique_ports=()
    for p in "${all_ports[@]}"; do
        if [[ ! -v seen["$p"] ]]; then
            seen["$p"]=1
            unique_ports+=("$p")
        fi
    done

    info "Ports to allow: ${unique_ports[*]}"

    ufw --force reset 2>/dev/null || true
    ufw default deny incoming
    ufw default allow outgoing

    for port in "${unique_ports[@]}"; do
        ufw allow "$port/tcp" 2>/dev/null || true
        step "Allowed port $port"
    done

    ufw --force enable
    log "Smart firewall configured."
}

open_port() {
    read -rp "$(echo -e "${CYAN}Port number:${NC} ")" port
    read -rp "$(echo -e "${CYAN}Protocol [tcp/udp] (default: tcp):${NC} ")" proto
    proto="${proto:-tcp}"

    ufw allow "${port}/${proto}" 2>/dev/null || {
        error "Failed to open port."
        return
    }

    echo "$port" >> "$WHITELIST_FILE"
    log "Port $port/$proto opened and added to whitelist."
}

close_port() {
    read -rp "$(echo -e "${CYAN}Port number to close:${NC} ")" port
    read -rp "$(echo -e "${CYAN}Protocol [tcp/udp] (default: tcp):${NC} ")" proto
    proto="${proto:-tcp}"

    if grep -q "^${port}$" "$WHITELIST_FILE" 2>/dev/null; then
        warn "This port is in the whitelist!"
        read -rp "$(echo -e "${RED}Are you sure you want to close it? [y/N]:${NC} ")" confirm
        [[ ! "$confirm" =~ ^[Yy]$ ]] && return
        sed -i "/^${port}$/d" "$WHITELIST_FILE" 2>/dev/null || true
    fi

    ufw deny "${port}/${proto}" 2>/dev/null || true
    log "Port $port/$proto closed."
}

enable_ufw() {
    ufw --force enable
    log "UFW enabled."
}

disable_ufw() {
    warn "Disabling UFW reduces server security!"
    read -rp "$(echo -e "${RED}Are you sure? [y/N]:${NC} ")" confirm
    [[ "$confirm" =~ ^[Yy]$ ]] && ufw disable && warn "UFW disabled."
}

manage_whitelist() {
    echo -e "\n${CYAN}Port Whitelist:${NC}"
    if [[ -f "$WHITELIST_FILE" ]]; then
        cat -n "$WHITELIST_FILE"
    else
        info "Whitelist is empty."
    fi
    echo ""
    echo "1) Add port"
    echo "2) Remove port"
    echo "0) Back"
    read -rp "Select: " choice
    case "$choice" in
        1) read -rp "Port: " p; echo "$p" >> "$WHITELIST_FILE"; log "Port $p added to whitelist." ;;
        2) read -rp "Port to remove: " p; sed -i "/^${p}$/d" "$WHITELIST_FILE"; log "Port $p removed from whitelist." ;;
        0) return ;;
    esac
}

# ─────────────────────────────────────────────────────────────
# MODULE 6: ENABLE SERVICES
# ─────────────────────────────────────────────────────────────
enable_menu() {
    while true; do
        echo -e "\n${BOLD}${GREEN}╔══════════════════════════════════════╗${NC}"
        echo -e "${BOLD}${GREEN}║          Enable Services             ║${NC}"
        echo -e "${BOLD}${GREEN}╚══════════════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${GREEN} 1)${NC}  Nginx"
        echo -e "  ${GREEN} 2)${NC}  Apache"
        echo -e "  ${GREEN} 3)${NC}  MySQL / MariaDB"
        echo -e "  ${GREEN} 4)${NC}  PostgreSQL"
        echo -e "  ${GREEN} 5)${NC}  MongoDB"
        echo -e "  ${GREEN} 6)${NC}  Redis"
        echo -e "  ${GREEN} 7)${NC}  RabbitMQ"
        echo -e "  ${GREEN} 8)${NC}  Docker"
        echo -e "  ${GREEN} 9)${NC}  Fail2Ban"
        echo -e "  ${GREEN}10)${NC}  UFW Firewall"
        echo -e "  ${GREEN}11)${NC}  Cron"
        echo -e "  ${GREEN}12)${NC}  SSH"
        echo -e "  ${GREEN}13)${NC}  Auditd"
        echo -e "  ${GREEN}14)${NC}  ClamAV"
        echo -e "  ${RED} 0)${NC}  Back"
        echo ""
        read -rp "$(echo -e "${CYAN}Select:${NC} ")" choice

        case "$choice" in
            1)  enable_service nginx ;;
            2)  enable_service apache2 httpd ;;
            3)  enable_service mysql mariadb ;;
            4)  enable_service postgresql ;;
            5)  enable_service mongod ;;
            6)  enable_service redis redis-server ;;
            7)  enable_service rabbitmq-server ;;
            8)  enable_service docker ;;
            9)  enable_service fail2ban ;;
            10) enable_ufw ;;
            11) enable_service cron crond ;;
            12) enable_service ssh sshd ;;
            13) enable_service auditd ;;
            14) enable_service clamav-daemon clamd ;;
            0)  return ;;
            *)  warn "Invalid option." ;;
        esac
    done
}

enable_service() {
    local found=false
    for svc in "$@"; do
        if systemctl list-unit-files "${svc}.service" &>/dev/null 2>&1; then
            systemctl enable "$svc" && systemctl start "$svc"
            log "Service '$svc' enabled and started."
            found=true
            break
        fi
    done
    $found || warn "Service '$1' not found on this system."
}

# ─────────────────────────────────────────────────────────────
# MODULE 7: DISABLE SERVICES
# ─────────────────────────────────────────────────────────────
disable_menu() {
    while true; do
        echo -e "\n${BOLD}${RED}╔══════════════════════════════════════╗${NC}"
        echo -e "${BOLD}${RED}║          Disable Services            ║${NC}"
        echo -e "${BOLD}${RED}╚══════════════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${YELLOW} 1)${NC}  Nginx"
        echo -e "  ${YELLOW} 2)${NC}  Apache"
        echo -e "  ${YELLOW} 3)${NC}  MySQL / MariaDB"
        echo -e "  ${YELLOW} 4)${NC}  PostgreSQL"
        echo -e "  ${YELLOW} 5)${NC}  MongoDB"
        echo -e "  ${YELLOW} 6)${NC}  Redis"
        echo -e "  ${YELLOW} 7)${NC}  RabbitMQ"
        echo -e "  ${YELLOW} 8)${NC}  Docker"
        echo -e "  ${YELLOW} 9)${NC}  Fail2Ban"
        echo -e "  ${YELLOW}10)${NC}  UFW Firewall"
        echo -e "  ${YELLOW}11)${NC}  Postfix (Mail)"
        echo -e "  ${YELLOW}12)${NC}  Auditd"
        echo -e "  ${YELLOW}13)${NC}  ClamAV"
        echo -e "  ${RED}14)${NC}  SSH  -- DANGER: will cut remote access!"
        echo -e "  ${RED} 0)${NC}  Back"
        echo ""
        read -rp "$(echo -e "${CYAN}Select:${NC} ")" choice

        case "$choice" in
            1)  disable_service nginx ;;
            2)  disable_service apache2 httpd ;;
            3)  disable_service mysql mariadb ;;
            4)  disable_service postgresql ;;
            5)  disable_service mongod ;;
            6)  disable_service redis redis-server ;;
            7)  disable_service rabbitmq-server ;;
            8)  disable_service docker ;;
            9)  disable_service fail2ban ;;
            10) disable_ufw ;;
            11) disable_service postfix ;;
            12) disable_service auditd ;;
            13) disable_service clamav-daemon clamd ;;
            14)
                warn "Disabling SSH will cut all remote access!"
                read -rp "$(echo -e "${RED}Type YES to confirm:${NC} ")" confirm
                [[ "$confirm" == "YES" ]] && disable_service ssh sshd || info "Aborted."
                ;;
            0)  return ;;
            *)  warn "Invalid option." ;;
        esac
    done
}

disable_service() {
    local found=false
    for svc in "$@"; do
        if systemctl list-unit-files "${svc}.service" &>/dev/null 2>&1; then
            systemctl stop "$svc" && systemctl disable "$svc"
            log "Service '$svc' stopped and disabled."
            found=true
            break
        fi
    done
    $found || warn "Service '$1' not found on this system."
}

# ─────────────────────────────────────────────────────────────
# MODULE 8: STATUS OVERVIEW
# ─────────────────────────────────────────────────────────────
show_status() {
    section "Server Status"

    echo -e "${BOLD}System Info:${NC}"
    echo -e "  OS:      $(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d'"' -f2 || uname -s)"
    echo -e "  Kernel:  $(uname -r)"
    echo -e "  Uptime:  $(uptime -p 2>/dev/null || uptime)"
    echo -e "  Load:    $(cut -d' ' -f1-3 /proc/loadavg)"
    echo ""

    echo -e "${BOLD}Disk Usage:${NC}"
    df -h --output=target,pcent,used,size | grep -v tmpfs | grep -v udev | head -10
    echo ""

    echo -e "${BOLD}Memory:${NC}"
    free -h
    echo ""

    echo -e "${BOLD}Active Ports:${NC}"
    ss -tlnup 2>/dev/null | grep LISTEN | awk '{print $4}' | grep -oP ':\K[0-9]+' | sort -un | tr '\n' ' '
    echo ""

    echo -e "\n${BOLD}UFW Status:${NC}"
    ufw status 2>/dev/null | head -5 || info "UFW not installed."

    echo -e "\n${BOLD}Key Services:${NC}"
    local services=("ssh" "nginx" "apache2" "mysql" "postgresql" "docker" "fail2ban" "ufw")
    for svc in "${services[@]}"; do
        if systemctl list-unit-files "${svc}.service" &>/dev/null 2>&1; then
            if systemctl is-active --quiet "$svc"; then
                echo -e "  ${GREEN}●${NC} $svc: running"
            else
                echo -e "  ${RED}●${NC} $svc: inactive"
            fi
        fi
    done

    echo -e "\n${BOLD}Recent Failed Logins:${NC}"
    lastb 2>/dev/null | head -5 || \
        journalctl -u ssh --no-pager -n 5 2>/dev/null | grep -i fail || \
        info "No data available."
}

# ─────────────────────────────────────────────────────────────
# MODULE 9: VIEW LOGS
# ─────────────────────────────────────────────────────────────
view_logs() {
    echo -e "\n${CYAN}Available Logs:${NC}"
    ls -lh "$LOG_DIR"/ 2>/dev/null || info "No logs yet."
    echo ""
    echo "1) View latest log"
    echo "2) View specific log"
    echo "0) Back"
    read -rp "Select: " choice
    case "$choice" in
        1) tail -50 "$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -1)" ;;
        2)
            read -rp "Log filename: " fname
            tail -50 "$LOG_DIR/$fname" 2>/dev/null || error "File not found."
            ;;
        0) return ;;
    esac
}

# ─────────────────────────────────────────────────────────────
# HELPER: DETECT DISTRO
# ─────────────────────────────────────────────────────────────
detect_distro() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        echo "${ID,,}"
    elif command -v apt-get &>/dev/null; then
        echo "debian"
    elif command -v yum &>/dev/null; then
        echo "centos"
    else
        echo "unknown"
    fi
}

# ─────────────────────────────────────────────────────────────
# ENTRY POINT
# ─────────────────────────────────────────────────────────────
require_root
show_banner
main_menu
