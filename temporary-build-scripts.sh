#!/bin/bash
# run as lfs user

# TODO: Extract filename from wget-list

source ~/.bashrc

# Fail on error
set -e

pushd $LFS/sources


# -------- Functions for temporary system --------
# Binutils-2.32 - Pass 1
function temporary-binutils-pass1()
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
function temporary-gcc-pass1()
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
function temporary-linux_headers()
{
  make mrproper
  make INSTALL_HDR_PATH=dest headers_install
  cp -rv dest/include/* /tools/include
}

# Glibc-2.29
function temporary-glibc()
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

#  Libstdc++
function temporary-libstd()
{
  mkdir -v build
  cd       build
  ../libstdc++-v3/configure           \
    --host=$LFS_TGT                 \
    --prefix=/tools                 \
    --disable-multilib              \
    --disable-nls                   \
    --disable-libstdcxx-threads     \
    --disable-libstdcxx-pch         \
    --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/8.2.0
    make
    make install
}

# Binutils-2.32 - Pass 2
function temporary-binutils-pass2()
{
  mkdir -v build
  cd       build
  CC=$LFS_TGT-gcc                \
  AR=$LFS_TGT-ar                 \
  RANLIB=$LFS_TGT-ranlib         \
  ../configure                   \
    --prefix=/tools            \
    --disable-nls              \
    --disable-werror           \
    --with-lib-path=/tools/lib \
    --with-sysroot
  make
  make install
  make -C ld clean
  make -C ld LIB_PATH=/usr/lib:/lib
  cp -v ld/ld-new /tools/bin
}

#  GCC-8.2.0 - Pass 2
function temporary-gcc-pass2()
{
  cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
  `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/include-fixed/limits.h

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
  tar -xf ../mpfr-4.0.2.tar.xz
  mv -v mpfr-4.0.2 mpfr
  tar -xf ../gmp-6.1.2.tar.xz
  mv -v gmp-6.1.2 gmp
  tar -xf ../mpc-1.1.0.tar.gz
  mv -v mpc-1.1.0 mpc
  mkdir -v build
  cd       build
  CC=$LFS_TGT-gcc                                    \
  CXX=$LFS_TGT-g++                                   \
  AR=$LFS_TGT-ar                                     \
  RANLIB=$LFS_TGT-ranlib                             \
  ../configure                                       \
      --prefix=/tools                                \
      --with-local-prefix=/tools                     \
      --with-native-system-header-dir=/tools/include \
      --enable-languages=c,c++                       \
      --disable-libstdcxx-pch                        \
      --disable-multilib                             \
      --disable-bootstrap                            \
      --disable-libgomp
  make
  make install
  ln -sv gcc /tools/bin/cc

    # Check if installation was successful!
  echo 'int main(){}' > dummy.c
  cc dummy.c
  readelf -l a.out | grep ': /tools'
  if [ $? -eq 1 ]; then
    echo "Linking did not work!"
    exit 1
  fi
  rm -v dummy.c a.out
}

# Tcl-8.6.9
function temporary-tcl()
{
  cd unix
  ./configure --prefix=/tools
  make
  make install
  chmod -v u+w /tools/lib/libtcl8.6.so
  make install-private-headers
  ln -sv tclsh8.6 /tools/bin/tclsh
}

# Expect-5.45.4
function temporary-expect()
{
  cp -v configure{,.orig}
  sed 's:/usr/local/bin:/bin:' configure.orig > configure
  ./configure --prefix=/tools       \
            --with-tcl=/tools/lib \
            --with-tclinclude=/tools/include
  make
  make SCRIPTS="" install
}

# DejaGNU-1.6.2
function temporary-dejagnu()
{
  ./configure --prefix=/tools
  make
  make install
}

# M4-1.4.18
function temporary-m4()
{
  sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' lib/*.c
  echo "#define _IO_IN_BACKUP 0x100" >> lib/stdio-impl.h
  ./configure --prefix=/tools
  make
  make install
}

# Ncurses-6.1
function temporary-ncurses()
{
  sed -i s/mawk// configure
  ./configure --prefix=/tools \
            --with-shared   \
            --without-debug \
            --without-ada   \
            --enable-widec  \
            --enable-overwrite
  make
  make install
  ln -s libncursesw.so /tools/lib/libncurses.so
}

# Bash-5.0
function temporary-bash()
{
  ./configure --prefix=/tools --without-bash-malloc
  make
  make install
  ln -sv bash /tools/bin/sh
}

# Bison-3.3.2
function temporary-bison()
{
  ./configure --prefix=/tools
  make
  make install
}

# Bzip2-1.0.6
function temporary-bzip2()
{
  make
  make PREFIX=/tools install
}

# Coreutils-8.30
function temporary-coreutils()
{
  ./configure --prefix=/tools --enable-install-program=hostname
  make
  make install
}

# Diffutils-3.7
function temporary-diffutils()
{
  ./configure --prefix=/tools
  make
  make install
}

# File-5.36
function temporary-file()
{
  ./configure --prefix=/tools
  make
  make install
}

#  Findutils-4.6.0
function temporary-findutils()
{
  sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' gl/lib/*.c
  sed -i '/unistd/a #include <sys/sysmacros.h>' gl/lib/mountlist.c
  echo "#define _IO_IN_BACKUP 0x100" >> gl/lib/stdio-impl.h
  ./configure --prefix=/tools
  make
  make install
}

# Gawk-4.2.1
function temporary-gawk()
{
  ./configure --prefix=/tools
  make
  make install
}

# Gettext-0.19.8.1
function temporary-gettext()
{
  cd gettext-tools
  EMACS="no" ./configure --prefix=/tools --disable-shared
  make -C gnulib-lib
  make -C intl pluralx.c
  make -C src msgfmt
  make -C src msgmerge
  make -C src xgettext
  cp -v src/{msgfmt,msgmerge,xgettext} /tools/bin
}

# Grep-3.3
function temporary-grep()
{
  ./configure --prefix=/tools
  make
  make install
}

# Gzip-1.10
function temporary-gzip()
{
  ./configure --prefix=/tools
  make
  make install
}

# Make-4.2.1
function temporary-make()
{
  sed -i '211,217 d; 219,229 d; 232 d' glob/glob.c
  ./configure --prefix=/tools --without-guile
  make
  make install
}

# Patch-2.7.6
function temporary-patch()
{
  ./configure --prefix=/tools
  make
  make install
}

# Perl-5.28.1
function temporary-perl()
{
  sh Configure -des -Dprefix=/tools -Dlibs=-lm -Uloclibpth -Ulocincpth
  make
  cp -v perl cpan/podlators/scripts/pod2man /tools/bin
  mkdir -pv /tools/lib/perl5/5.28.1
  cp -Rv lib/* /tools/lib/perl5/5.28.1
}

# Python-3.7.2
function temporary-python()
{
  sed -i '/def add_multiarch_paths/a \        return' setup.py
  ./configure --prefix=/tools --without-ensurepip
  make
  make install
}

# Sed-4.7
function temporary-sed()
{
  ./configure --prefix=/tools
  make
  make install
}

# Tar-1.31
function temporary-tar()
{
  ./configure --prefix=/tools
  make
  make install
}

# Texinfo-6.5
function temporary-texinfo()
{
  ./configure --prefix=/tools
  make
  make install
}

# Xz-5.2.4
function temporary-xz()
{
  ./configure --prefix=/tools
  make
  make install
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

# run needed installations for temporary system
install_package binutils-2.32.tar.xz temporary-binutils-pass1
install_package gcc-8.2.0.tar.xz temporary-gcc-pass1
install_package linux-4.20.12.tar.xz temporary-linux_headers
install_package glibc-2.29.tar.xz temporary-glibc
install_package gcc-8.2.0.tar.xz temporary-libstd
install_package binutils-2.32.tar.xz temporary-binutils-pass2
install_package gcc-8.2.0.tar.xz temporary-gcc-pass2
install_package tcl8.6.9-src.tar.gz temporary-tcl
install_package expect5.45.4.tar.gz temporary-expect5
install_package dejagnu-1.6.2.tar.gz temporary-dejagnu
install_package m4-1.4.18.tar.xz temporary-m4
install_package ncurses-6.1.tar.gz temporary-ncurses
install_package bash-5.0.tar.gz temporary-bash
install_package bison-3.3.2.tar.xz temporary-bison
install_package bzip2-1.0.6.tar.gz temporary-bzip2
install_package coreutils-8.30.tar.xz temporary-coreutils
install_package diffutils-3.7.tar.xz temporary-diffutils
install_package file-5.36.tar.gz temporary-file
install_package findutils-4.6.0.tar.gz temporary-findutils
install_package gawk-4.2.1.tar.xz temporary-gawk
install_package gettext-0.19.8.1.tar.xz temporary-gettext
install_package grep-3.3.tar.xz temporary-grep
install_package gzip-1.10.tar.xz temporary-gzip
install_package make-4.2.1.tar.bz2 temporary-make
install_package patch-2.7.6.tar.xz temporary-patch
install_package perl-5.28.1.tar.xz temporary-perl
install_package Python-3.7.2.tar.xz temporary-Python
install_package sed-4.7.tar.xz temporary-sed
install_package tar-1.31.tar.xz temporary-tar
install_package texinfo-6.5.tar.xz temporary-texinfo
install_package xz-5.2.4.tar.xz temporary-xz

popd