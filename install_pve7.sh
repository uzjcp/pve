#!/bin/bash
#from https://github.com/spiritLHLS/pve
# pve 7

# 前置环境安装
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi
if ! command -v wget > /dev/null 2>&1; then
      apt-get install -y wget
fi
if ! command -v curl > /dev/null 2>&1; then
      apt-get install -y curl
fi
if ! command -v ufw > /dev/null 2>&1; then
      apt-get install -y ufw
fi
apt-get install gnupg -y
ufw disable

# 修改 /etc/hosts
ip=$(curl -s ipv4.ip.sb)
line_number=$(tac /etc/hosts | grep -n "^127\.0\.0\.1" | head -n 1 | awk -F: '{print $1}')
echo "$ip pve.proxmox.com pve" | tee -a /etc/hosts > /dev/null
sed -i "${line_number} a $ip pve.proxmox.com pve" /etc/hosts

# 新增pve源
version=$(lsb_release -cs)
if [ "$version" == "jessie" ]; then
  repo_url="deb https://mirrors.tuna.tsinghua.edu.cn/proxmox/debian/pve jessie pve-no-subscription"
elif [ "$version" == "stretch" ]; then
  repo_url="deb https://mirrors.tuna.tsinghua.edu.cn/proxmox/debian/pve stretch pve-no-subscription"
elif [ "$version" == "buster" ]; then
  repo_url="deb https://mirrors.tuna.tsinghua.edu.cn/proxmox/debian/pve buster pve-no-subscription"
  wget https://github.com/spiritLHLS/pve/raw/main/gpg/proxmox-release-buster.gpg -O /etc/apt/trusted.gpg.d/proxmox-release-buster.gpg
  apt-key add /etc/apt/trusted.gpg.d/proxmox-release-buster.gpg
elif [ "$version" == "bullseye" ]; then
  repo_url="deb https://mirrors.tuna.tsinghua.edu.cn/proxmox/debian/pve bullseye pve-no-subscription"
  wget http://download.proxmox.com/debian/proxmox-release-bullseye.gpg -O /etc/apt/trusted.gpg.d/proxmox-release-bullseye.gpg
  apt-key add /etc/apt/trusted.gpg.d/proxmox-release-bullseye.gpg
else
  echo "Error: Unsupported Debian version"
  exit 1
fi
echo "$repo_url" >> /etc/apt/sources.list

# 下载pve
apt-get update && apt-get full-upgrade
apt-get install debian-keyring debian-archive-keyring -y
apt-get autoremove
apt-get update
apt-get -y install proxmox-ve postfix open-iscsi

# 检查pve
if ! nc -z localhost 7789; then
  iptables -A INPUT -p tcp --dport 7789 -j ACCEPT
  iptables-save > /etc/iptables.rules
fi
result=$(journalctl -xe | grep "/etc/pve/local/pve-ssl.key: failed to load local private key (key_file or key) at /usr/share/perl5/PVE/APIServer/AnyEvent.pm line")
if [ -n "$result" ]; then
  pvecm createcert
  systemctl restart pve-manager
fi

