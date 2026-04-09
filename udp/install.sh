#!/bin/bash
# zivpn source : zahidbd2
# udp custom  : 
# script by lunatic.
# ========================================
# COLOR SYSTEM
# ========================================
NC='\e[0m'
WHITE='\033[1;97m'
CYAN='\033[38;5;51m'
CYAN_SOFT='\033[38;5;117m'
GREEN='\033[38;5;82m'
RED='\033[38;5;196m'
YELLOW='\033[1;33m'
ORANGE='\e[38;5;130m'
DIM='\033[2m'

clear

# ========================================
# HEADER
# ========================================
echo -e "${CYAN_SOFT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}${WHITE}        ZIVPN & UDP CUSTOM INSTALLER${NC}"
echo -e "${CYAN_SOFT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e " ${WHITE}System Overview:${NC}"
echo -e "   ${CYAN}•${NC} Engine        : ZIVPN UDP Core"
echo -e "   ${CYAN}•${NC} Mode          : High Performance UDP Tunnel"
echo -e "   ${CYAN}•${NC} Integration   : Kernel NAT & Custom UDP"
echo -e "   ${CYAN}•${NC} Security      : SSL + IP Filtering"
echo -e "   ${CYAN}•${NC} Status        : INITIALIZING"

echo -e "${CYAN_SOFT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# ========================================
# PERMISSION CHECK
# ========================================
echo -e " ${WHITE}Permission Validation:${NC}"

IP=$(wget -qO- ipinfo.io/ip || echo "")

if [[ -z "$IP" ]]; then
    echo -e "${RED}✖ Unable to detect server IP${NC}"
    exit 1
fi

DB_URL="https://raw.githubusercontent.com/yansyntax/permission/main/regist"
DB=$(wget -qO- $DB_URL || echo "")

EXP=$(echo "$DB" | grep -w "$IP" | awk '{print $2}' | head -n1)

if [[ -z "$EXP" ]]; then
    echo -e "${RED}✖ Permission Denied${NC}"
    echo -e " ${WHITE}IP${NC} : $IP not registered"
    exit 1
fi

NOW=$(date +%Y-%m-%d)

if [[ "$NOW" > "$EXP" ]]; then
    echo -e "${RED}✖ License Expired${NC}"
    echo -e " ${WHITE}Expired${NC} : $EXP"
    exit 1
fi

echo -e "${GREEN}✔ Permission Granted${NC}"
echo -e " ${WHITE}Expired${NC} : $EXP"

# ========================================
# ARCH DETECT
# ========================================
echo -e "\n ${WHITE}System Detection:${NC}"

ARCH=$(uname -m)

case "$ARCH" in
    x86_64)
        BIN_URL="https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64"
        ARCH_TYPE="AMD64"
        ;;
    aarch64|arm64)
        BIN_URL="https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-arm64"
        ARCH_TYPE="ARM64"
        ;;
    *)
        echo -e "${RED}✖ Unsupported Architecture${NC}"
        exit 1
        ;;
esac

echo -e " ${CYAN}•${NC} Architecture : ${WHITE}$ARCH_TYPE${NC}"

# ========================================
# CLEAN INSTALL
# ========================================
echo -e "\n ${WHITE}Preparing Environment:${NC}"

systemctl stop zivpn 2>/dev/null
rm -rf /etc/zivpn /usr/local/bin/zivpn

# ========================================
# INSTALL DEPENDENCY
# ========================================
echo -e " ${WHITE}Installing Dependencies:${NC}"
apt-get update -y >/dev/null
apt-get install -y wget curl openssl iptables-persistent >/dev/null

# ========================================
# INSTALL ZIVPN
# ========================================
echo -e " ${WHITE}Installing ZIVPN Core:${NC}"

mkdir -p /etc/zivpn
wget -qO /usr/local/bin/zivpn $BIN_URL
chmod +x /usr/local/bin/zivpn

# CONFIG
wget -qO /etc/zivpn/config.json https://raw.githubusercontent.com/yansyntax/error404/main/udp/config.json

# SSL
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
-subj "/C=US/ST=CA/O=LUNATIC/CN=zivpn" \
-keyout /etc/zivpn/zivpn.key \
-out /etc/zivpn/zivpn.crt >/dev/null 2>&1

# ========================================
# CREATE DEFAULT USER
# ========================================
echo -e " ${WHITE}Initializing Database:${NC}"

DB="/etc/zivpn/users.db"
mkdir -p /etc/lunatic/zivpn/{ip,logip,detail}

EXP_UNIX=$(date -d "+9999 days" +%s)
echo "zi:${EXP_UNIX}" > $DB

# ========================================
# SERVICE
# ========================================
echo -e " ${WHITE}Configuring Service:${NC}"

cat >/etc/systemd/system/zivpn.service <<EOF
[Unit]
Description=Lunatic ZIVPN UDP Engine
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/zivpn server -c /etc/zivpn/config.json
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable zivpn >/dev/null
systemctl restart zivpn

# ========================================
# UDP CUSTOM
# ========================================
echo -e " ${WHITE}Deploying UDP Custom:${NC}"

rm -rf /usr/bin/udp /usr/bin/udp-custom
mkdir -p /usr/bin/udp

wget -qO /usr/bin/udp-custom "https://drive.google.com/uc?id=1ixz82G_ruRBnEEp4vLPNF2KZ1k8UfrkV"
chmod +x /usr/bin/udp-custom

wget -qO /usr/bin/udp/config.json "https://drive.google.com/uc?id=1klXTiKGUd2Cs5cBnH3eK2Q1w50Yx3jbf"

# ========================================
# NAT CONFIG
# ========================================
echo -e " ${WHITE}Applying Network Rules:${NC}"

IFACE=$(ip -4 route | awk '/default/ {print $5; exit}')
iptables -t nat -A PREROUTING -i "$IFACE" -p udp --dport 6000:19999 -j DNAT --to :5667 2>/dev/null

iptables-save > /etc/iptables/rules.v4

# ========================================
# RESULT
# ========================================
STATUS=$(systemctl is-active zivpn)

clear

echo -e "${CYAN_SOFT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}              INSTALLATION SUCCESSFUL${NC}"
echo -e "${CYAN_SOFT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo ""
echo -e " ${WHITE}Service Information:${NC}"
echo -e "   ${CYAN}•${NC} Service     : ZIVPN UDP Engine"
echo -e "   ${CYAN}•${NC} Status      : ${GREEN}${STATUS^^}${NC}"
echo -e "   ${CYAN}•${NC} Mode        : High Performance Tunnel"

echo ""
echo -e " ${WHITE}Network Configuration:${NC}"
echo -e "   ${CYAN}•${NC} Interface   : $IFACE"
echo -e "   ${CYAN}•${NC} UDP Range   : 6000 - 19999"
echo -e "   ${CYAN}•${NC} Forward Port: 5667"

echo ""
echo -e " ${WHITE}Security Layer:${NC}"
echo -e "   ${CYAN}•${NC} Encryption  : SSL/TLS"
echo -e "   ${CYAN}•${NC} Protocol    : UDP Tunnel"
echo -e "   ${CYAN}•${NC} Access      : Controlled"

echo -e "${CYAN_SOFT}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""