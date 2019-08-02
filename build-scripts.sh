#!/bin/bash

# Fail on error
set -e

pushd $LFS/sources

# Binutils-2.32 - Pass 1
function binutils-pass1()
{
  mkdir -v build
  cd build
  ../configure --prefix=/tools            \
              --with-sysroot=$LFS        \
              --with-lib-path=/tools/lib \
              --target=$LFS_TGT          \
              --disable-nls              \
              --disable-werror
  make
  case $(uname -m) in
    x86_64) mkdir -v /tools/lib && ln -sv lib /tools/lib64 ;;
  esac
  make install
}

# GCC-8.2.0 - Pass 1
function gcc-pass1()
{
  tar -xf ../mpfr-4.0.2.tar.xz
  mv -v mpfr-4.0.2 mpfr
  tar -xf ../gmp-6.1.2.tar.xz
  mv -v gmp-6.1.2 gmp
  tar -xf ../mpc-1.1.0.tar.gz
  mv -v mpc-1.1.0 mpc

  for file in gcc/config/{linux,i386/linux{,64}}.h
  do
    cp -uv $file{,.orig}
    sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
        -e 's@/usr@/tools@g' $file.orig > $file
    echo '
  #undef STANDARD_STARTFILE_PREFIX_1
  #undef STANDARD_STARTFILE_PREFIX_2
  #define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
  #define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
    touch $file.orig
  done

  case $(uname -m) in
    x86_64)
      sed -e '/m64=/s/lib64/lib/' \
          -i.orig gcc/config/i386/t-linux64
  ;;
  esac

  mkdir -v build
  cd       build

  ../configure                                       \
      --target=$LFS_TGT                              \
      --prefix=/tools                                \
      --with-glibc-version=2.11                      \
      --with-sysroot=$LFS                            \
      --with-newlib                                  \
      --without-headers                              \
      --with-local-prefix=/tools                     \
      --with-native-system-header-dir=/tools/include \
      --disable-nls                                  \
      --disable-shared                               \
      --disable-multilib                             \
      --disable-decimal-float                        \
      --disable-threads                              \
      --disable-libatomic                            \
      --disable-libgomp                              \
      --disable-libmpx                               \
      --disable-libquadmath                          \
      --disable-libssp                               \
      --disable-libvtv                               \
      --disable-libstdcxx                            \
      --enable-languages=c,c++

  make
  make install
}

#  Linux-4.20.12 API Headers
function linux_headers()
{
  pushd linux-4.20.12
  make mrproper
  make INSTALL_HDR_PATH=dest headers_install
  cp -rv dest/include/* /tools/include
}

# Glibc-2.29
function glibc()
{
  mkdir -v build
  cd build
  ../configure                             \
      --prefix=/tools                    \
      --host=$LFS_TGT                    \
      --build=$(../scripts/config.guess) \
      --enable-kernel=3.2                \
      --with-headers=/tools/include
  make
  make install

  # Check if installation was successful!
  echo 'int main(){}' > dummy.c
  $LFS_TGT-gcc dummy.c
  readelf -l a.out | grep ': /tools'
  if [ $? -eq 1 ]; then
    echo "Linking did not work!"
    exit 1
  fi
}

# Function for extracting packages, removing folders after installation etc.
# $1 archive to process
# $2 function for a package to run
function install_package()
{
  # As of now, all archives are tar based
  filefullname=$(basename -- "$1")
  foldername="${filefullname%.tar*}"
  extension="${filefullname##$foldername}"
  tar -xf $filefullname
  pushd $foldername

  # Call main configuration function
  $2

  # Cleanup
  popd
  rm -rf $foldername
}

# run needed installations
install_package binutils-2.32.tar.xz binutils-pass1
install_package gcc-8.2.0.tar.xz gcc-pass1
install_package linux-4.20.12.tar.xz linux_headers
install_package glibc-2.29.tar.xz glibc

popd