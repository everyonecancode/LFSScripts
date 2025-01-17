#!/bin/bash

set -e
# Make drive bootable
grub-install $1

# Create grub configuration file
cat > /boot/grub/grub.cfg << "EOF"
# Begin /boot/grub/grub.cfg
set default=0
set timeout=5

insmod ext4
set root=(hd0,${2})

menuentry "GNU/Linux, Linux 4.20.12-lfs-8.4" {
        linux   /boot/vmlinuz-4.20.12-lfs-8.4 root=${1}${2} ro
}
EOF
