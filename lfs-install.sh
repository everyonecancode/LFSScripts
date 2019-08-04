#!/bin/bash
# This script assumes, that the basic filesystem is already created and we are running as root

# Check if we are root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root"
  exit 1
fi

# Fix for debian
PATH=$PATH:/usr/sbin:/sbin

# Variables
LFS=/mnt/lfs
wget_timout=30

# Get sources and prepare LFS specific directories
mkdir -v $LFS/sources
wget http://www.linuxfromscratch.org/lfs/view/stable/wget-list

# dowload files
while [ $wget_timout -gt 0 ]; do
  wget --input-file=wget-list --continue --directory-prefix=$LFS/sources && break
  let "$wget_timeout--"
done

if [ $wget_timout -eq 0 ]; then
  echo "Error occured while downloading packages"
  exit 1
fi

# Fail on error
set -e

# Fix for inconsistent file names
mv $LFS/sources/tcl8.6.9-src.tar.gz $LFS/sources/tcl8.6.9.tar.gz

chmod -v a+wt $LFS/sources
mkdir -v $LFS/tools
ln -sv $LFS/tools /

# Create LFS build user and group and change folders ownerships
groupadd lfs
useradd -s /bin/bash -g lfs -m -k /dev/null lfs
chown -v lfs $LFS/tools
chown -v lfs $LFS/sources

# Prepare bash script for LFS user
cat > /home/lfs/.bash_profile << "EOF"
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF

cat > /home/lfs/.bashrc << "EOF"
set +h
umask 022
LFS=/mnt/lfs
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/tools/bin:/bin:/usr/bin
MAKEFLAGS='-j12'
export LFS LC_ALL LFS_TGT PATH MAKEFLAGS
EOF
chown -v lfs /home/lfs/.bash_profile
chown -v lfs /home/lfs/.bashrc

# Build temporary files
su -c ./temporary-build-scripts.sh lfs

# Change ownership of tools to root
chown -R root:root $LFS/tools

# Create kernel filesystem
mkdir -pv $LFS/{dev,proc,sys,run}
mknod -m 600 $LFS/dev/console c 5 1
mknod -m 666 $LFS/dev/null c 1 3
mount -v --bind /dev $LFS/dev
mount -vt devpts devpts $LFS/dev/pts -o gid=5,mode=620
mount -vt proc proc $LFS/proc
mount -vt sysfs sysfs $LFS/sys
mount -vt tmpfs tmpfs $LFS/run
if [ -h $LFS/dev/shm ]; then
  mkdir -pv $LFS/$(readlink $LFS/dev/shm)
fi

# TODO: For now no package management is needed. Fix for later?

# Chroot to new environment. Using new script for that.
cp final-build.scripts.sh $LFS
chroot "$LFS" final-build.scripts.sh