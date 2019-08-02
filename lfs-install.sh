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

# ensure exit on fail
set -e

# Get sources and prepare LFS specific directories
mkdir -v $LFS/sources
wget http://www.linuxfromscratch.org/lfs/view/stable/wget-list
wget --input-file=wget-list --continue --directory-prefix=$LFS/sources
chmod -v a+wt $LFS/sources
mkdir -v $LFS/tools
ln -sv $LFS/tools /

# Create LFS build user and group and change folders ownerships
groupadd lfs
useradd -s /bin/bash -g lfs -m -k /dev/null lfs
chown -v lfs $LFS/tools
chown -v lfs $LFS/sources

sudo -i -u lfs ./build-scripts.sh
