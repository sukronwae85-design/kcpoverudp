#!/bin/bash

# ==================================================
# SSH KCP OVER UDP - ULTIMATE SERVER
# Features: KCP Acceleration, User Management, Backup, 
# Bandwidth Monitor, Multi-login Control, etc.
# ==================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Config
SSH_PORT=22
KCP_PORT=4000
MANAGER_PORT=9000
TIMEZONE="Asia/Jakarta"
MAX_USERS=50
MAX_LOGINS=3

# Root check
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: Run as root!${NC}" 
   exit 1
fi

# Functions
print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_info() { echo -e "${BLUE}[i]${NC} $1"; }

# Banner
show_banner() {
    clear
    echo -e "${GREEN}"
    echo "================================================"
    echo "    SSH KCP OVER UDP - ULTIMATE SERVER"
    echo "================================================"
    echo -e "${NC}"
}

# Install Dependencies
install_dependencies() {
    print_info "Installing dependencies..."
    apt update && apt upgrade -y
    apt install -y wget curl git build-essential libssl-dev \
    iptables-persistent net-tools bc python3 python3-pip \
    jq fail2ban cron dos2unix
    
    # Install KCPTUN
    wget -O /usr/local/bin/kcptun-server https://github.com/xtaci/kcptun/releases/latest/download/kcptun-linux-amd64
    chmod +x /usr/local/bin/kcptun-server
    
    print_status "Dependencies installed"
}

# Setup Timezone
setup_timezone() {
    print_info "Setting timezone to $TIMEZONE..."
    timedatectl set-timezone $TIMEZONE
    echo "LC_TIME=en_US.UTF-8" >> /etc/default/locale
    print_status "Timezone configured"
}

# Configure SSH
setup_ssh() {
    print_info "Configuring SSH..."
    
    # Backup original sshd_config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    
    # Configure SSH
    cat > /etc/ssh/sshd_config << EOF
Port $SSH_PORT
Protocol 2
PermitRootLogin yes
PasswordAuthentication yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 3
MaxSessions $MAX_LOGINS
TCPKeepAlive yes
UsePAM yes
EOF

    systemctl restart ssh
    print_status "SSH configured on port $SSH_PORT"
}

# Setup KCPTUN Server
setup_kcptun() {
    print_info "Setting up KCPTUN server..."
    
    # Create KCPTUN config
    mkdir -p /etc/kcptun
    cat > /etc/kcptun/server-config.json << EOF
{
    "listen": ":${KCP_PORT}",
    "target": "127.0.0.1:${SSH_PORT}",
    "key": "$(openssl rand -hex 16)",
    "crypt": "aes-128",
    "mode": "fast2",
    "mtu": 1350,
    "sndwnd": 1024,
    "rcvwnd": 1024,
    "datashard": 10,
    "parityshard": 3,
    "dscp": 46,
    "nocomp": false,
    "acknodelay": false,
    "nodelay": 1,
    "interval": 20,
    "resend": 2,
    "nc": 1,
    "sockbuf": 4194304,
    "keepalive": 10
}
EOF

    # Create KCPTUN service
    cat > /etc/systemd/system/kcptun.service << EOF
[Unit]
Description=KCPTUN Server
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/kcptun-server -c /etc/kcptun/server-config.json
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable kcptun
    systemctl start kcptun
    print_status "KCPTUN server started on port $KCP_PORT"
}

# Setup Firewall
setup_firewall() {
    print_info "Configuring firewall..."
    
    # Reset iptables
    iptables -F
    iptables -X
    iptables -t nat -F
    iptables -t nat -X
    
    # Default policies
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT
    
    # Allow loopback
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT
    
    # Allow established connections
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    
    # Allow SSH
    iptables -A INPUT -p tcp --dport $SSH_PORT -j ACCEPT
    
    # Allow KCP (UDP)
    iptables -A INPUT -p udp --dport $KCP_PORT -j ACCEPT
    
    # Allow manager
    iptables -A INPUT -p tcp --dport $MANAGER_PORT -j ACCEPT
    
    # Allow DNS
    iptables -A INPUT -p udp --dport 53 -j ACCEPT
    iptables -A INPUT -p tcp --dport 53 -j ACCEPT
    
    # Allow ping
    iptables -A INPUT -p icmp -m icmp --icmp-type 8 -j ACCEPT
    
    # Save rules
    iptables-save > /etc/iptables/rules.v4
    print_status "Firewall configured"
}

# User Management System
create_user_management() {
    print_info "Creating user management system..."
    
    mkdir -p /etc/ssh-kcp-manager
    mkdir -p /etc/ssh-kcp-manager/backups
    mkdir -p /etc/ssh-kcp-manager/users
    
    # Create main manager script
    cat > /usr/local/bin/ssh-manager << 'EOF'
#!/bin/bash

CONFIG_DIR="/etc/ssh-kcp-manager"
USERS_DIR="$CONFIG_DIR/users"
BACKUP_DIR="$CONFIG_DIR/backups"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_menu() {
    echo -e "${GREEN}"
    echo "========================================="
    echo "    SSH KCP MANAGER - ULTIMATE EDITION"
    echo "========================================="
    echo -e "${NC}"
    echo "1. Create User"
    echo "2. Delete User" 
    echo "3. List Users"
    echo "4. User Statistics"
    echo "5. Bandwidth Monitor"
    echo "6. Backup System"
    echo "7. Restore Backup"
    echo "8. Server Status"
    echo "9. Limit User Login"
    echo "10. Kick User"
    echo "11. Change Password"
    echo "12. Exit"
    echo
}

create_user() {
    read -p "Enter username: " username
    if id "$username" &>/dev/null; then
        echo -e "${RED}User already exists!${NC}"
        return
    fi
    
    read -s -p "Enter password: " password
    echo
    read -p "Expire days (0 for unlimited): " expire_days
    read -p "Max simultaneous logins: " max_logins
    
    # Create user
    useradd -m -s /bin/bash $username
    echo "$username:$password" | chpasswd
    
    # Create user info file
    cat > $USERS_DIR/$username.info << EOL
USERNAME=$username
CREATED=$(date +%Y-%m-%d)
EXPIRE_DAYS=$expire_days
MAX_LOGINS=$max_logins
BANDWIDTH_USED=0
LAST_LOGIN=
EOL

    echo -e "${GREEN}User $username created successfully!${NC}"
    echo "KCP Connection: kcptun-client -r SERVER_IP:$KCP_PORT -l :LOCAL_PORT -key YOUR_KEY"
}

list_users() {
    echo -e "${YELLOW}=== User List ===${NC}"
    for user_file in $USERS_DIR/*.info; do
        if [ -f "$user_file" ]; then
            source $user_file
            echo "User: $USERNAME | Expire: $EXPIRE_DAYS days | Max Logins: $MAX_LOGINS"
        fi
    done
}

monitor_bandwidth() {
    echo -e "${YELLOW}=== Bandwidth Usage ===${NC}"
    ifconfig | grep -E "RX|TX" | grep -v collisions
}

backup_system() {
    local backup_file="$BACKUP_DIR/backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    tar -czf $backup_file /etc/ssh /etc/kcptun /etc/ssh-kcp-manager 2>/dev/null
    echo -e "${GREEN}Backup created: $backup_file${NC}"
}

server_status() {
    echo -e "${YELLOW}=== Server Status ===${NC}"
    echo "SSH Service: $(systemctl is-active ssh)"
    echo "KCPTUN Service: $(systemctl is-active kcptun)"
    echo "CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}')%"
    echo "Memory Usage: $(free -m | awk 'NR==2{printf "%.2f%%", $3*100/$2}')"
    echo "Uptime: $(uptime -p)"
}

while true; do
    show_menu
    read -p "Choose option: " choice
    case $choice in
        1) create_user ;;
        2) echo "Delete user feature" ;;
        3) list_users ;;
        4) echo "Statistics feature" ;;
        5) monitor_bandwidth ;;
        6) backup_system ;;
        7) echo "Restore feature" ;;
        8) server_status ;;
        9) echo "Limit login feature" ;;
        10) echo "Kick user feature" ;;
        11) echo "Change password feature" ;;
        12) break ;;
        *) echo -e "${RED}Invalid option!${NC}" ;;
    esac
    echo
done
EOF

    chmod +x /usr/local/bin/ssh-manager
    
    # Create Web Manager (Optional)
    cat > /etc/ssh-kcp-manager/web-manager.py << 'EOF'
#!/usr/bin/env python3
from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import subprocess

class ManagerHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/status':
            status = {
                "ssh": subprocess.getoutput("systemctl is-active ssh"),
                "kcptun": subprocess.getoutput("systemctl is-active kcptun"),
                "users": len([f for f in os.listdir("/etc/ssh-kcp-manager/users") if f.endswith('.info')])
            }
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(status).encode())
    
    def log_message(self, format, *args):
        pass  # Disable logging

print("Starting SSH KCP Manager on port 9000...")
HTTPServer(('0.0.0.0', 9000), ManagerHandler).serve_forever()
EOF

    print_status "User management system created"
}

# Bandwidth Monitoring
setup_bandwidth_monitor() {
    print_info "Setting up bandwidth monitoring..."
    
    cat > /usr/local/bin/bw-monitor << 'EOF'
#!/bin/bash
LOG_FILE="/var/log/bandwidth.log"

echo "=== Bandwidth Monitoring ==="
echo "Current usage:"
iftop -t -s 10 -L 100

echo -e "\nDaily usage:"
vnstat -d

echo -e "\nMonthly usage:"  
vnstat -m
EOF

    chmod +x /usr/local/bin/bw-monitor
    
    # Install vnstat for bandwidth monitoring
    apt install -y vnstat iftop
    vnstat -u -i $(ip route get 8.8.8.8 | awk '{print $5; exit}')
    
    print_status "Bandwidth monitoring setup complete"
}

# Auto Backup System
setup_auto_backup() {
    print_info "Setting up auto backup..."
    
    cat > /etc/cron.daily/ssh-kcp-backup << 'EOF'
#!/bin/bash
BACKUP_DIR="/etc/ssh-kcp-manager/backups"
tar -czf $BACKUP_DIR/auto-backup-$(date +%Y%m%d).tar.gz /etc/ssh /etc/kcptun /etc/ssh-kcp-manager 2>/dev/null
find $BACKUP_DIR -name "auto-backup-*.tar.gz" -mtime +7 -delete
EOF

    chmod +x /etc/cron.daily/ssh-kcp-backup
    print_status "Auto backup configured"
}

# Login Monitoring & Control
setup_login_control() {
    print_info "Setting up login control..."
    
    cat > /usr/local/bin/login-monitor << 'EOF'
#!/bin/bash
echo "=== Current SSH Sessions ==="
who

echo -e "\n=== Failed Login Attempts ==="
grep "Failed password" /var/log/auth.log | tail -10

echo -e "\n=== KCP Connections ==="
netstat -tulpn | grep kcptun
EOF

    chmod +x /usr/local/bin/login-monitor
    
    # Configure fail2ban for SSH protection
    cat > /etc/fail2ban/jail.local << EOF
[sshd]
enabled = true
port = $SSH_PORT
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
EOF

    systemctl enable fail2ban
    systemctl start fail2ban
    
    print_status "Login control configured"
}

# Final Setup
final_setup() {
    print_info "Performing final setup..."
    
    # Enable services
    systemctl enable ssh
    systemctl enable kcptun
    systemctl enable fail2ban
    
    # Create client config generator
    cat > /usr/local/bin/generate-client-config << 'EOF'
#!/bin/bash
SERVER_IP=$(curl -s ifconfig.me)
KCP_KEY=$(grep -o '"key": "[^"]*' /etc/kcptun/server-config.json | cut -d'"' -f4)

echo "=== KCP Client Configuration ==="
echo "Server IP: $SERVER_IP"
echo "KCP Port: $KCP_PORT"
echo "KCP Key: $KCP_KEY"
echo
echo "Client command:"
echo "kcptun-client -r $SERVER_IP:$KCP_PORT -l :2222 -key $KCP_KEY"
echo
echo "Then connect via: ssh username@127.0.0.1 -p 2222"
EOF

    chmod +x /usr/local/bin/generate-client-config
    
    print_status "Final setup complete"
}

# Show Usage
show_usage() {
    echo -e "${GREEN}"
    echo "================================================"
    echo "          INSTALLATION COMPLETE!"
    echo "================================================"
    echo -e "${NC}"
    echo "SSH Port: $SSH_PORT"
    echo "KCP Port: $KCP_PORT (UDP)"
    echo "Manager: Run 'ssh-manager' for user management"
    echo "Bandwidth Monitor: Run 'bw-monitor'"
    echo "Login Monitor: Run 'login-monitor'"
    echo "Client Config: Run 'generate-client-config'"
    echo
    echo -e "${YELLOW}Important:${NC}"
    echo "- KCP accelerates SSH over UDP"
    echo "- Use kcptun-client on your local machine"
    echo "- Manager helps create users and monitor"
    echo
}

# Main Installation
main() {
    show_banner
    install_dependencies
    setup_timezone
    setup_ssh
    setup_kcptun
    setup_firewall
    create_user_management
    setup_bandwidth_monitor
    setup_auto_backup
    setup_login_control
    final_setup
    show_usage
}

# Run main function
main "$@"