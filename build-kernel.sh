#!/bin/bash

set -e
pushd /sources
tar -xf linux-4.20.12.tar.xz
pushd linux-4.20.12

mkdir -pv /usr/pkg/linux/4.20.12/usr/share/doc/linux-4.20.12/
make mrproper
make defconfig
make
make modules_install
cp -fv arch/x86/boot/bzImage /boot/vmlinuz-4.20.12-lfs-8.4
cp -fv System.map /boot/System.map-4.20.12
cp -fv .config /boot/config-4.20.12
install -d /usr/pkg/linux/4.20.12/share/doc/linux-4.20.12
cp -rv Documentation/*  /usr/pkg/linux/4.20.12/usr/share/doc/linux-4.20.12

# Create links for documentation
cp -rvs /usr/pkg/linux/4.20.12/usr/share/doc/linux-4.20.12/* /usr/share/doc/linux-4.20.12/


# Create modprobe config file
install -v -m755 -d /etc/modprobe.d
cat > /etc/modprobe.d/usb.conf << "EOF"
# Begin /etc/modprobe.d/usb.conf

install ohci_hcd /sbin/modprobe ehci_hcd ; /sbin/modprobe -i ohci_hcd ; true
install uhci_hcd /sbin/modprobe ehci_hcd ; /sbin/modprobe -i uhci_hcd ; true

# End /etc/modprobe.d/usb.conf
EOF

popd
popd