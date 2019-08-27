#!/bin/bash

# Make drive bootable
grub-install /dev/sda

# Create grub configuration file
cat > /boot/grub/grub.cfg << "EOF"
# Begin /boot/grub/grub.cfg
set default=0
set timeout=5

insmod ext4
set root=(hd0,1)

menuentry "GNU/Linux, Linux 4.20.12-lfs-8.4" {
        linux   /boot/vmlinuz-4.20.12-lfs-8.4 root=/dev/sda2 ro
}
EOF
