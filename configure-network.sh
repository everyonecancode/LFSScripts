#!/bin/bash

set -e
DOMAIN=lfs

# Configure eth0 network interface
cat > /etc/sysconfig/ifconfig.eth0 << "EOF"
ONBOOT=yes
IFACE=eth0
SERVICE=ipv4-static
IP=192.168.1.2
GATEWAY=192.168.1.1
PREFIX=24
BROADCAST=192.168.1.255
EOF

# Configure for OpenDNS
cat > /etc/resolv.conf << "EOF"
# Begin /etc/resolv.conf

domain $DOMAIN.com
nameserver 208.67.222.222
nameserver 208.67.220.220

# End /etc/resolv.conf
EOF

# Setup hostname
echo $DOMAIN > /etc/hostname

# Setup hosts file
cat > /etc/hosts << "EOF"
# Begin /etc/hosts

127.0.0.1 localhost
::1       localhost ip6-localhost ip6-loopback
ff02::1   ip6-allnodes
ff02::2   ip6-allrouters

# End /etc/hosts
EOF