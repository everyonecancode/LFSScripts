#!/bin/bash

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
drive=
number=

## Obtain drive to  install grub to
while [ "$1" != ""]; do
  case $1 in
    -p | --partition) shift
      drive=$1
      ;;
    -n | --number) shift
      number=$1
  esac
  shift
done

if [ -z "$drive"]
then
  echo "Please specify drive in the form of /dev/sdx. I really don't want to mess your system with grub installation"
  exit 1
fi
if [ -z "$number"]
then
  echo "Please specify boot partition number [i.e. '1']. I really don't want to mess your system with grub installation"
  exit 1
fi

# Get sources and prepare LFS specific directories
mkdir -v $LFS/sources

# dowload files
while [ $wget_timout -gt 0 ]; do
  # break if no error
  wget --input-file=wget-list --continue --directory-prefix=$LFS/sources && break

  # break when number of files downloaded are equal to the number
  # of lines in wget-list
  # ls -f returns also . and .. folders, so the number of files in
  # folder should be decremented by 2
  # WARNING!!!
  # This is working workaround, but it does not consider the possiblity
  # of downloading incomplete file. If such thing happens, the build will
  # fail.
  # TODO:? Improve this to consider incomplete or broken files
  if [ $(cat wget-list | wc -l) -eq $(($(ls -f $LFS/sources/ | wc -l)-2)) ]; then
    break
  fi
  ((wget_timeout--))

  # There is an issue with ftp.gnu.org certificates when running
  # wget continously. Sleep should fix that.
  sleep 5
done

if [ $wget_timout -eq 0 ]; then
  echo "Error occured while downloading packages"
  exit 1
fi

# Fail on error
set -e

# Fix for inconsistent file names
mv $LFS/sources/tcl8.6.9-src.tar.gz $LFS/sources/tcl8.6.9.tar.gz
mv $LFS/sources/vim-8.1.tar.bz2 $LFS/sources/vim81.tar.bz2

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

# Chroot to new environment. Using new script for that.
cp final-build-scripts.sh configure-network.sh configure-system.sh build-kernel.sh install-grub.sh $LFS/

# Build system software
HOME=/root TERM="$TERM" PS1='(lfs chroot) \u:\w\$ ' PATH=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin /sbin/chroot "$LFS" /tools/bin/bash +h final-build-scripts.sh

# Configure network
HOME=/root TERM="$TERM" PS1='(lfs chroot) \u:\w\$ ' PATH=/bin:/usr/bin:/sbin:/usr/sbin /sbin/chroot "$LFS" /bin/bash +h configure-network.sh

# System configuration
HOME=/root TERM="$TERM" PS1='(lfs chroot) \u:\w\$ ' PATH=/bin:/usr/bin:/sbin:/usr/sbin /sbin/chroot "$LFS" /bin/bash +h configure-system.sh

# Build default x86 linux kernel
HOME=/root TERM="$TERM" PS1='(lfs chroot) \u:\w\$ ' PATH=/bin:/usr/bin:/sbin:/usr/sbin /sbin/chroot "$LFS" /bin/bash +h build-kernel.sh

# Install GRUB
HOME=/root TERM="$TERM" PS1='(lfs chroot) \u:\w\$ ' PATH=/bin:/usr/bin:/sbin:/usr/sbin /sbin/chroot "$LFS" /bin/bash +h install-grub.sh $drive $number