#!/tools/bin/bash

set -e

# Create directories
mkdir -pv /{bin,boot,etc/{opt,sysconfig},home,lib/firmware,mnt,opt}
mkdir -pv /{media/{floppy,cdrom},sbin,srv,var}
install -dv -m 0750 /root
install -dv -m 1777 /tmp /var/tmp
mkdir -pv /usr/{,local/}{bin,include,lib,sbin,src}
mkdir -pv /usr/{,local/}share/{color,dict,doc,info,locale,man}
mkdir -v  /usr/{,local/}share/{misc,terminfo,zoneinfo}
mkdir -v  /usr/libexec
mkdir -pv /usr/{,local/}share/man/man{1..8}

case $(uname -m) in
 x86_64) mkdir -v /lib64 ;;
esac

mkdir -v /var/{log,mail,spool}
ln -sv /run /var/run
ln -sv /run/lock /var/lock
mkdir -pv /var/{opt,cache,lib/{color,misc,locate},local}

# Create symlinks
ln -sv /tools/bin/{bash,cat,chmod,dd,echo,ln,mkdir,pwd,rm,stty,touch} /bin
ln -sv /tools/bin/{env,install,perl,printf}         /usr/bin
ln -sv /tools/lib/libgcc_s.so{,.1}                  /usr/lib
ln -sv /tools/lib/libstdc++.{a,so{,.6}}             /usr/lib

install -vdm755 /usr/lib/pkgconfig

ln -sv bash /bin/sh
ln -sv /proc/self/mounts /etc/mtab

cat > /etc/passwd << "EOF"
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/bin/false
daemon:x:6:6:Daemon User:/dev/null:/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/var/run/dbus:/bin/false
nobody:x:99:99:Unprivileged User:/dev/null:/bin/false
EOF

cat > /etc/group << "EOF"
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
usb:x:14:
cdrom:x:15:
adm:x:16:
messagebus:x:18:
input:x:24:
mail:x:34:
kvm:x:61:
wheel:x:97:
nogroup:x:99:
users:x:999:
EOF

# TODO: Here we have exec /tools/bin/bash --login +h. Not needed, since it's a script?
touch /var/log/{btmp,lastlog,faillog,wtmp}
chgrp -v utmp /var/log/lastlog
chmod -v 664  /var/log/lastlog
chmod -v 600  /var/log/btmp

# change directory to sources
pushd /sources

# -------- Functions for final system --------

# Default installation function
function default()
{
  ./configure --prefix=/usr
  make
  # make check
  make DESTDIR=/usr/pkg/$1/$2 install
}

# Linux-4.20.12 API Headers
function final-linux()
{
  make mrproper
  make INSTALL_HDR_PATH=dest headers_install
  find dest/include \( -name .install -o -name ..install.cmd \) -delete
  mkdir -pv /usr/pkg/linux/4.20.12/include
  cp -rv dest/include/* /usr/pkg/linux/4.20.12/include
  cp -rvs  /usr/pkg/linux/4.20.12/include/* /usr/include/
}

# Man-pages-4.16
function final-manpages
{
  make DESTDIR=/usr/pkg/$1/$2/ install
}

# Glibc-2.29
function final-glibc()
{
  patch -Np1 -i ../glibc-2.29-fhs-1.patch
  ln -sfv /tools/lib/gcc /usr/lib
  case $(uname -m) in
      i?86)    GCC_INCDIR=/usr/lib/gcc/$(uname -m)-pc-linux-gnu/8.2.0/include
              ln -sfv ld-linux.so.2 /lib/ld-lsb.so.3
      ;;
      x86_64) GCC_INCDIR=/usr/lib/gcc/x86_64-pc-linux-gnu/8.2.0/include
              ln -sfv ../lib/ld-linux-x86-64.so.2 /lib64
              ln -sfv ../lib/ld-linux-x86-64.so.2 /lib64/ld-lsb-x86-64.so.3
      ;;
  esac
  rm -f /usr/include/limits.h
  mkdir -v build
  cd       build
  CC="gcc -isystem $GCC_INCDIR -isystem /usr/include" \
  ../configure --prefix=/usr                          \
              --disable-werror                       \
              --enable-kernel=3.2                    \
              --enable-stack-protector=strong        \
              libc_cv_slibdir=/lib
  unset GCC_INCDIR
  make
  case $(uname -m) in
    i?86)   ln -sfnv $PWD/elf/ld-linux.so.2        /lib ;;
    x86_64) ln -sfnv $PWD/elf/ld-linux-x86-64.so.2 /lib ;;
  esac
  # make check
  touch /etc/ld.so.conf
  sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile
  make DESTDIR=/usr/pkg/$1/$2/ install
  cp -v ../nscd/nscd.conf /etc/nscd.conf
  mkdir -pv /var/cache/nscd
  mkdir -pv /usr/lib/locale

  # Glibc must be installed on system before running
  # localedef. This should not break the build
  cp -rvs /usr/pkg/$1/$2/* /
  localedef -i POSIX -f UTF-8 C.UTF-8 2> /dev/null || true
  localedef -i cs_CZ -f UTF-8 cs_CZ.UTF-8
  localedef -i de_DE -f ISO-8859-1 de_DE
  localedef -i de_DE@euro -f ISO-8859-15 de_DE@euro
  localedef -i de_DE -f UTF-8 de_DE.UTF-8
  localedef -i el_GR -f ISO-8859-7 el_GR
  localedef -i en_GB -f UTF-8 en_GB.UTF-8
  localedef -i en_HK -f ISO-8859-1 en_HK
  localedef -i en_PH -f ISO-8859-1 en_PH
  localedef -i en_US -f ISO-8859-1 en_US
  localedef -i en_US -f UTF-8 en_US.UTF-8
  localedef -i es_MX -f ISO-8859-1 es_MX
  localedef -i fa_IR -f UTF-8 fa_IR
  localedef -i fr_FR -f ISO-8859-1 fr_FR
  localedef -i fr_FR@euro -f ISO-8859-15 fr_FR@euro
  localedef -i fr_FR -f UTF-8 fr_FR.UTF-8
  localedef -i it_IT -f ISO-8859-1 it_IT
  localedef -i it_IT -f UTF-8 it_IT.UTF-8
  localedef -i ja_JP -f EUC-JP ja_JP
  localedef -i ja_JP -f SHIFT_JIS ja_JP.SIJS 2> /dev/null || true
  localedef -i ja_JP -f UTF-8 ja_JP.UTF-8
  localedef -i pl_PL -f ISO-8859-2 pl_PL
  localedef -i ru_RU -f KOI8-R ru_RU.KOI8-R
  localedef -i ru_RU -f UTF-8 ru_RU.UTF-8
  localedef -i tr_TR -f UTF-8 tr_TR.UTF-8
  localedef -i zh_CN -f GB18030 zh_CN.GB18030
  localedef -i zh_HK -f BIG5-HKSCS zh_HK.BIG5-HKSCS
  make localedata/install-locales
}

# Zlib-1.2.11
function final-zlib()
{
  ./configure --prefix=/usr
  make
  # make check
  make DESTDIR=/usr/pkg/$1/$2/ install
  cp -v /usr/pkg/$1/$2/usr/lib/libz.so.* /lib
  ln -sfv ../../lib/$(readlink /usr/lib/libz.so) /usr/lib/libz.so
}

# Readline-8.0
function final-readline()
{
  sed -i '/MV.*old/d' Makefile.in
  sed -i '/{OLDSUFF}/c:' support/shlib-install
  ./configure --prefix=/usr    \
              --disable-static \
              --docdir=/usr/share/doc/readline-8.0
  make SHLIB_LIBS="-L/tools/lib -lncursesw"
  make SHLIB_LIBS="-L/tools/lib -lncursesw" DESTDIR=/usr/pkg/$1/$2/ install
  cp -v /usr/pkg/$1/$2/usr/lib/lib{readline,history}.so.* /lib
  chmod -v u+w /lib/lib{readline,history}.so.*
  ln -sfv ../../lib/$(readlink /usr/lib/libreadline.so) /usr/lib/libreadline.so
  ln -sfv ../../lib/$(readlink /usr/lib/libhistory.so ) /usr/lib/libhistory.so
  install -v -m644 doc/*.{ps,pdf,html,dvi} /usr/pkg/$1/$2/usr/share/doc/readline-8.0
}

# M4-1.4.18
function final-m4()
{
sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' lib/*.c
echo "#define _IO_IN_BACKUP 0x100" >> lib/stdio-impl.h
./configure --prefix=/usr
make
# make check
make DESTDIR=/usr/pkg/$1/$2/ install
}

# Bc-1.07.1
function final-bc()
{
  cat > bc/fix-libmath_h << "EOF"
    #! /bin/bash
    sed -e '1   s/^/{"/' \
        -e     's/$/",/' \
        -e '2,$ s/^/"/'  \
        -e   '$ d'       \
        -i libmath.h

    sed -e '$ s/$/0}/' \
        -i libmath.h
EOF
  ln -sv /tools/lib/libncursesw.so.6 /usr/lib/libncursesw.so.6
  ln -sfv libncursesw.so.6 /usr/lib/libncurses.so
  sed -i -e '/flex/s/as_fn_error/: ;; # &/' configure
  ./configure --prefix=/usr           \
              --with-readline         \
              --mandir=/usr/share/man \
              --infodir=/usr/share/info
  make
  # echo "quit" | ./bc/bc -l Test/checklib.b
  make DESTDIR=/usr/pkg/$1/$2/ install
}

# Binutils-2.32
function final-binutils()
{
  # TODO: Verify output
  expect -c "spawn ls"
  mkdir -v build
  cd       build
  ../configure --prefix=/usr       \
              --enable-gold       \
              --enable-ld=default \
              --enable-plugins    \
              --enable-shared     \
              --disable-werror    \
              --enable-64-bit-bfd \
              --with-system-zlib
  make tooldir=/usr/pkg/$1/$2/
  # make -k check
  make tooldir=/usr/pkg/$1/$2/ install
}

# GMP-6.1.2
function final-gmp()
{
  ./configure --prefix=/usr    \
              --enable-cxx     \
              --disable-static \
              --docdir=/usr/share/doc/gmp-6.1.2
  make
  make html
  # make check 2>&1 | tee gmp-check-log
  # awk '/# PASS:/{total+=$3} ; END{print total}' gmp-check-log
  make DESTDIR=/usr/pkg/$1/$2/ install
  make DESTDIR=/usr/pkg/$1/$2/ install-html
}

# MPFR-4.0.2
function final-mpfr()
{
  ./configure --prefix=/usr        \
              --disable-static     \
              --enable-thread-safe \
              --docdir=/usr/share/doc/mpfr-4.0.2
  make
  make html
  # make check
  make DESTDIR=/usr/pkg/$1/$2/ install
  make DESTDIR=/usr/pkg/$1/$2/ install-html
}

# MPC-1.1.0
function final-mpc()
{
  ./configure --prefix=/usr    \
              --disable-static \
              --docdir=/usr/share/doc/mpc-1.1.0
  make
  make html
  # make check
  make DESTDIR=/usr/pkg/$1/$2/ install
  make DESTDIR=/usr/pkg/$1/$2/ install-html
}

# Shadow-4.6
function final-shadow()
{
  sed -i 's/groups$(EXEEXT) //' src/Makefile.in
  find man -name Makefile.in -exec sed -i 's/groups\.1 / /'   {} \;
  find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
  find man -name Makefile.in -exec sed -i 's/passwd\.5 / /'   {} \;
  sed -i -e 's@#ENCRYPT_METHOD DES@ENCRYPT_METHOD SHA512@' \
        -e 's@/var/spool/mail@/var/mail@' etc/login.defs
  sed -i 's/1000/999/' etc/useradd
  ./configure --sysconfdir=/etc --with-group-name-max-length=32
  make
  make DESTDIR=/usr/pkg/$1/$2/ install
  cp -v /usr/pkg/$1/$2/usr/bin/passwd /bin
  
  # Shadow must be installed on system before running
  # commands below.
  cp -rvs /usr/pkg/$1/$2/* /
  pwconv
  grpconv
}

# GCC-8.2.0
function final-gcc()
{
  case $(uname -m) in
    x86_64)
      sed -e '/m64=/s/lib64/lib/' \
          -i.orig gcc/config/i386/t-linux64
    ;;
  esac
  rm -f /usr/lib/gcc
  mkdir -v build
  cd       build
  SED=sed                               \
  ../configure --prefix=/usr            \
              --enable-languages=c,c++ \
              --disable-multilib       \
              --disable-bootstrap      \
              --disable-libmpx         \
              --with-system-zlib
  make
  # ulimit -s 32768
  # rm ../gcc/testsuite/g++.dg/pr83239.C
  # chown -Rv nobody .
  # su nobody -s /bin/bash -c "PATH=$PATH make -k check"
  # ../contrib/test_summary
  make DESTDIR=/usr/pkg/$1/$2/ install

  # This is a corner case, where the package has to be fully installed
  # inside build function and not in general installation function.
  # This should, however, not break the build.
  cp -rfsv /usr/pkg/$1/$2/* /

  ln -sv ../usr/bin/cpp /lib
  ln -sv gcc /usr/bin/cc
  install -v -dm755 /usr/lib/bfd-plugins
  ln -sfv ../../libexec/gcc/$(gcc -dumpmachine)/8.2.0/liblto_plugin.so \
          /usr/lib/bfd-plugins/

  # Temporarily disable "stop on error" flag to enable logging of errors
  set +e

  # It seems that the build below sometimes fails, still pointing to library
  # located in /tools directory. Generating spec file seems to solve this
  gcc -dumpspecs | sed -e 's@/tools@@g' > `dirname $(gcc --print-libgcc-file-name)`/specs
  echo 'int main(){}' > dummy.c
  cc dummy.c -v -Wl,--verbose &> dummy.log
  readelf -l a.out | grep ': /lib'
  if [ $? -eq 1 ]; then
    echo "GCC: readelf -l a.out | grep ': /lib' failed "
    exit 1
  fi
  grep -o '/usr/lib.*/crt[1in].*succeeded' dummy.log
  if [ $? -eq 1 ]; then
    echo "GCC: grep -o '/usr/lib.*/crt[1in].*succeeded' dummy.log failed"
    exit 1
  fi
  grep -B1 '^ /usr/include' dummy.log
  if [ $? -eq 1 ]; then
    echo "GCC: grep -B1 '^ /usr/include' dummy.log failed"
    exit 1
  fi
  grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g'
  if [ $? -eq 1 ]; then
    echo "GCC: grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g' failed"
    exit 1
  fi
  grep "/lib.*/libc.so.6 " dummy.log
  if [ $? -eq 1 ]; then
    echo "GCC: grep /lib.*/libc.so.6 dummy.log failed"
    exit 1
  fi
  grep found dummy.log
  if [ $? -eq 1 ]; then
    echo "GCC: grep found dummy.log failed"
    exit 1
  fi
  set -e
  rm -v dummy.c a.out dummy.log
  mkdir -pv /usr/share/gdb/auto-load/usr/lib
  mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib
}

# Bzip2-1.0.6
function final-bzip2()
{
  patch -Np1 -i ../bzip2-1.0.6-install_docs-1.patch
  sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile
  sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile
  make -f Makefile-libbz2_so
  make clean
  make
  make PREFIX=/usr/pkg/$1/$2/usr install
  cp -v bzip2-shared /bin/bzip2
  cp -av libbz2.so* /lib
  ln -sv ../../lib/libbz2.so.1.0 /usr/lib/libbz2.so
  rm -v  /usr/pkg/$1/$2/usr/bin/{bunzip2,bzcat,bzip2}
  ln -sv bzip2 /bin/bunzip2
  ln -sv bzip2 /bin/bzcat
}

# Pkg-config-0.29.2
function final-pkgconfig()
{
  ./configure --prefix=/usr              \
              --with-internal-glib       \
              --disable-host-tool        \
              --docdir=/usr/share/doc/pkg-config-0.29.2
  make
  # make check
  make DESTDIR=/usr/pkg/$1/$2 install
}

# Ncurses-6.1
function final-ncurses()
{
  sed -i '/LIBTOOL_INSTALL/d' c++/Makefile.in
  ./configure --prefix=/usr           \
              --mandir=/usr/share/man \
              --with-shared           \
              --without-debug         \
              --without-normal        \
              --enable-pc-files       \
              --enable-widec
  make
  make DESTDIR=/usr/pkg/$1/$2 install
  cp -v /usr/pkg/$1/$2/usr/lib/libncursesw.so.6* /lib
  ln -sfv ../../lib/$(readlink /usr/lib/libncursesw.so) /usr/lib/libncursesw.so
  for lib in ncurses form panel menu ; do
      rm -vf                    /usr/pkg/$1/$2/usr/lib/lib${lib}.so
      echo "INPUT(-l${lib}w)" > /usr/pkg/$1/$2/usr/lib/lib${lib}.so
      ln -sfv ${lib}w.pc        /usr/pkg/$1/$2/usr/lib/pkgconfig/${lib}.pc
  done
  rm -vf                     /usr/pkg/$1/$2/usr/lib/libcursesw.so
  echo "INPUT(-lncursesw)" > /usr/pkg/$1/$2/usr/lib/libcursesw.so
  ln -sfv libncurses.so      /usr/pkg/$1/$2/usr/lib/libcurses.so
  mkdir -pv       /usr/pkg/$1/$2/usr/share/doc/ncurses-6.1
  cp -v -R doc/* /usr/pkg/$1/$2/usr/share/doc/ncurses-6.1
}

# Attr-2.4.48
function final-attr()
{
  ./configure --prefix=/usr     \
              --bindir=/bin     \
              --disable-static  \
              --sysconfdir=/etc \
              --docdir=/usr/share/doc/attr-2.4.48
  make
  # make check
  make DESTDIR=/usr/pkg/$1/$2 install
  cp -v /usr/pkg/$1/$2/usr/lib/libattr.so.* /lib
  ln -sfv ../../lib/$(readlink /usr/lib/libattr.so) /usr/lib/libattr.so
}

# Acl-2.2.53
function final-acl()
{
  ./configure --prefix=/usr         \
              --bindir=/bin         \
              --disable-static      \
              --libexecdir=/usr/lib \
              --docdir=/usr/share/doc/acl-2.2.53
  make
  make DESTDIR=/usr/pkg/$1/$2 install
  cp -v /usr/pkg/$1/$2/usr/lib/libacl.so.* /lib
  ln -sfv ../../lib/$(readlink /usr/lib/libacl.so) /usr/lib/libacl.so
}

# Libcap-2.26
function final-libcap()
{
  sed -i '/install.*STALIBNAME/d' libcap/Makefile
  make
  make RAISE_SETFCAP=no lib=lib prefix=/usr/pkg/$1/$2/usr install
  chmod -v 755 /usr/pkg/$1/$2/usr/lib/libcap.so.2.26
  cp -v /usr/pkg/$1/$2/usr/lib/libcap.so.* /lib
  ln -sfv ../../lib/$(readlink /usr/lib/libcap.so) /usr/lib/libcap.so
}

# Sed-4.7
function final-sed()
{
  sed -i 's/usr/tools/'                 build-aux/help2man
  sed -i 's/testsuite.panic-tests.sh//' Makefile.in
  ./configure --prefix=/usr --bindir=/bin
  make
  make html
  # make check
  make DESTDIR=/usr/pkg/$1/$2 install
  install -d -m755           /usr/pkg/$1/$2/usr/share/doc/sed-4.7
  install -m644 doc/sed.html /usr/pkg/$1/$2/usr/share/doc/sed-4.7
}

# Psmisc-23.2
function final-psmisc()
{
  default "psmisc" "23.2"
  cp -v /usr/pkg/psmisc/23.2/usr/bin/fuser   /bin
  mv -v /usr/pkg/psmisc/23.2/usr/bin/killall /bin
}

# Iana-Etc-2.30
function final-iana()
{
  make
  make DESTDIR=/usr/pkg/$1/$2/usr install
}

# Bison-3.3.2
function final-bison()
{
  ./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.3.2
  make
  make DESTDIR=/usr/pkg/$1/$2 install
}

# Flex-2.6.4
function final-flex()
{
  sed -i "/math.h/a #include <malloc.h>" src/flexdef.h
  HELP2MAN=/tools/bin/true \
  ./configure --prefix=/usr --docdir=/usr/share/doc/flex-2.6.4
  make
  # make check
  make DESTDIR=/usr/pkg/$1/$2 install
  ln -sv flex /usr/bin/lex
}

# Grep-3.3
function final-grep()
{
  ./configure --prefix=/usr --bindir=/bin
  make
  # make -k check
  make DESTDIR=/usr/pkg/$1/$2 install
}

# Bash-5.0
function final-bash()
{
  ./configure --prefix=/usr                    \
              --docdir=/usr/share/doc/bash-5.0 \
              --without-bash-malloc            \
              --with-installed-readline
  make
  chown -Rv nobody .
  # su nobody -s /bin/bash -c "PATH=$PATH HOME=/home make tests"
  make DESTDIR=/usr/pkg/$1/$2 install
  cp -vf /usr/pkg/$1/$2/usr/bin/bash /bin
}

# GDBM-1.18.1
function final-gdbm()
{
  ./configure --prefix=/usr    \
              --disable-static \
              --enable-libgdbm-compat
  make
  # make check
  make DESTDIR=/usr/pkg/$1/$2 install
}

# Gperf-3.1
function final-gperf()
{
  ./configure --prefix=/usr --docdir=/usr/share/doc/gperf-3.1
  make
  # make -j1 check
  make DESTDIR=/usr/pkg/$1/$2 install
}

# Expat-2.2.6
function final-expat()
{
  sed -i 's|usr/bin/env |bin/|' run.sh.in
  ./configure --prefix=/usr    \
              --disable-static \
              --docdir=/usr/share/doc/expat-2.2.6
  make
  # make check
  make DESTDIR=/usr/pkg/$1/$2 install
  install -v -m644 doc/*.{html,png,css} /usr/pkg/$1/$2/usr/share/doc/expat-2.2.6
}

# Inetutils-1.9.4
function final-inetutils()
{
  ./configure --prefix=/usr        \
              --localstatedir=/var \
              --disable-logger     \
              --disable-whois      \
              --disable-rcp        \
              --disable-rexec      \
              --disable-rlogin     \
              --disable-rsh        \
              --disable-servers
  make
  # make check
  make DESTDIR=/usr/pkg/$1/$2 install
  mv -v /usr/pkg/$1/$2/usr/bin/{hostname,ping,ping6,traceroute} /bin
  mv -v /usr/pkg/$1/$2/usr/bin/ifconfig /sbin
}

# Perl-5.28.1
function final-perl()
{
  echo "127.0.0.1 localhost $(hostname)" > /etc/hosts
  export BUILD_ZLIB=False
  export BUILD_BZIP2=0
  sh Configure -des -Dprefix=/usr                 \
                    -Dvendorprefix=/usr           \
                    -Dman1dir=/usr/share/man/man1 \
                    -Dman3dir=/usr/share/man/man3 \
                    -Dpager="/usr/bin/less -isR"  \
                    -Duseshrplib                  \
                    -Dusethreads
  make
  # make -k test
  make DESTDIR=/usr/pkg/$1/$2 install
  unset BUILD_ZLIB BUILD_BZIP2
}

# XML::Parser-2.44
function final-xmlparser()
{
  perl Makefile.PL
  make
#  make test
  make DESTDIR=/usr/pkg/$1/$2 install
}

# Intltool-0.51.0
function final-intltool()
{
  sed -i 's:\\\${:\\\$\\{:' intltool-update.in
  default "intltool" "0.51.0"
  install -v -Dm644 doc/I18N-HOWTO /usr/pkg/$1/$2/usr/share/doc/intltool-0.51.0/I18N-HOWTO
}

# Autoconf-2.69
function final-autoconf()
{
  sed '361 s/{/\\{/' -i bin/autoscan.in
  default "autoconf" "2.69"
}

# Automake-1.16.1
function final-automake()
{
  ./configure --prefix=/usr --docdir=/usr/share/doc/automake-1.16.1
  make
  # make -j4 check
  make DESTDIR=/usr/pkg/$1/$2 install
}

# Xz-5.2.4
function final-xz()
{
  ./configure --prefix=/usr    \
              --disable-static \
              --docdir=/usr/share/doc/xz-5.2.4
  make
  # make check
  make DESTDIR=/usr/pkg/$1/$2 install
  cp -v   /usr/pkg/$1/$2/usr/bin/{lzma,unlzma,lzcat,xz,unxz,xzcat} /bin
  cp -v   /usr/pkg/$1/$2/usr/lib/liblzma.so.* /lib
  ln -svf ../../lib/$(readlink /usr/lib/liblzma.so) /usr/lib/liblzma.so
}

# Kmod-26
function final-kmod()
{
  ./configure --prefix=/usr          \
              --bindir=/bin          \
              --sysconfdir=/etc      \
              --with-rootlibdir=/lib \
              --with-xz              \
              --with-zlib
  make
  make DESTDIR=/usr/pkg/$1/$2 install

  for target in depmod insmod lsmod modinfo modprobe rmmod; do
    ln -sfv ../bin/kmod /sbin/$target
  done

  ln -sfv kmod /bin/lsmod
}

# Gettext-0.19.8.1
function final-gettext()
{
  sed -i '/^TESTS =/d' gettext-runtime/tests/Makefile.in &&
  sed -i 's/test-lock..EXEEXT.//' gettext-tools/gnulib-tests/Makefile.in
  sed -e '/AppData/{N;N;p;s/\.appdata\./.metainfo./}' \
      -i gettext-tools/its/appdata.loc
  ./configure --prefix=/usr    \
              --disable-static \
              --docdir=/usr/share/doc/gettext-0.19.8.1
  make
  # make check
  make DESTDIR=/usr/pkg/$1/$2 install
  chmod -v 0755 /usr/pkg/$1/$2/usr/lib/preloadable_libintl.so
}

# Libelf from Elfutils-0.176
function final-libelf()
{
  ./configure --prefix=/usr
  make
  # make check
  make -C libelf DESTDIR=/usr/pkg/$1/$2 install

  # create directory for storing pkconfig file
  mkdir -pv /usr/pkg/$1/$2/usr/lib/pkgconfig
  install -vm644 config/libelf.pc /usr/pkg/$1/$2/usr/lib/pkgconfig/
}

# Libffi-3.2.1
function final-libffi()
{
  sed -e '/^includesdir/ s/$(libdir).*$/$(includedir)/' \
      -i include/Makefile.in

  sed -e '/^includedir/ s/=.*$/=@includedir@/' \
      -e 's/^Cflags: -I${includedir}/Cflags:/' \
      -i libffi.pc.in
  ./configure --prefix=/usr --disable-static --with-gcc-arch=native
  make
  # make check
  make DESTDIR=/usr/pkg/$1/$2 install
}

# OpenSSL-1.1.1a
function final-openssl()
{
  ./config --prefix=/usr         \
          --openssldir=/etc/ssl \
          --libdir=lib          \
          shared                \
          zlib-dynamic
  make
#  make test
  sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
  make MANSUFFIX=ssl DESTDIR=/usr/pkg/$1/$2 install
  mv -v /usr/pkg/$1/$2/usr/share/doc/openssl /usr/pkg/$1/$2/usr/share/doc/openssl-1.1.1a
  cp -vfr doc/* /usr/pkg/$1/$2/usr/share/doc/openssl-1.1.1a
}

# Python-3.7.2
function final-python()
{
  ./configure --prefix=/usr       \
              --enable-shared     \
              --with-system-expat \
              --with-system-ffi   \
              --with-ensurepip=yes
  make
  make DESTDIR=/usr/pkg/$1/$2 install
  chmod -v 755 /usr/pkg/$1/$2/usr/lib/libpython3.7m.so
  chmod -v 755 /usr/pkg/$1/$2/usr/lib/libpython3.so
  install -v -dm755 /usr/pkg/$1/$2/usr/share/doc/python-3.7.2/html

  tar --strip-components=1  \
      --no-same-owner       \
      --no-same-permissions \
      -C /usr/pkg/$1/$2/usr/share/doc/python-3.7.2/html \
      -xvf ../python-3.7.2-docs-html.tar.bz2
}

# Ninja-1.9.0
function final-ninja()
{
  python3 configure.py --bootstrap
  python3 configure.py
#  ./ninja ninja_test
#  ./ninja_test --gtest_filter=-SubprocessTest.SetWithLots
  mkdir -pv /usr/pkg/$1/$2/usr/bin/
  mkdir -pv /usr/pkg/$1/$2/usr/share/bash-completion/completions/
  mkdir -pv /usr/pkg/$1/$2/usr/share/zsh/site-functions/
  install -vm755 ninja /usr/pkg/$1/$2/usr/bin/
  install -vDm644 misc/bash-completion /usr/pkg/$1/$2/usr/share/bash-completion/completions/ninja
  install -vDm644 misc/zsh-completion  /usr/pkg/$1/$2/usr/share/zsh/site-functions/_ninja
}

# Meson-0.49.2
function final-meson()
{
  python3 setup.py build
  python3 setup.py install --root=dest
  cp -rv dest/* /usr/pkg/$1/$2/
}

# Coreutils-8.30
function final-coreutils()
{
  patch -Np1 -i ../coreutils-8.30-i18n-1.patch
  sed -i '/test.lock/s/^/#/' gnulib-tests/gnulib.mk
  autoreconf -fiv
  FORCE_UNSAFE_CONFIGURE=1 ./configure \
              --prefix=/usr            \
              --enable-no-install-program=kill,uptime
  FORCE_UNSAFE_CONFIGURE=1 make
  # make NON_ROOT_USERNAME=nobody check-root
  # echo "dummy:x:1000:nobody" >> /etc/group
  # chown -Rv nobody .
  # su nobody -s /bin/bash \
  #           -c "PATH=$PATH make RUN_EXPENSIVE_TESTS=yes check"
  sed -i '/dummy/d' /etc/group
  make DESTDIR=/usr/pkg/$1/$2 install

  mkdir -pv /usr/pkg/$1/$2/bin
  mkdir -pv /usr/pkg/$1/$2/usr/sbin
  mkdir -pv /usr/pkg/$1/$2/usr/share/man/man8
  cp -v /usr/pkg/$1/$2/usr/bin/{cat,chgrp,chmod,chown,cp,date,dd,df,echo} /usr/pkg/$1/$2/bin
  cp -v /usr/pkg/$1/$2/usr/bin/{false,ln,ls,mkdir,mknod,mv,pwd,rm} /usr/pkg/$1/$2/bin
  cp -v /usr/pkg/$1/$2/usr/bin/{rmdir,stty,sync,true,uname} /usr/pkg/$1/$2/bin
  mv -v /usr/pkg/$1/$2/usr/bin/chroot /usr/pkg/$1/$2/usr/sbin
  mv -v /usr/pkg/$1/$2/usr/share/man/man1/chroot.1 /usr/pkg/$1/$2/usr/share/man/man8/chroot.8
  sed -i s/\"1\"/\"8\"/1 /usr/pkg/$1/$2/usr/share/man/man8/chroot.8
  cp -v /usr/pkg/$1/$2/usr/bin/{head,nice,sleep,touch} /usr/pkg/$1/$2/bin
}

# Check-0.12.0
function final-check()
{
  default "check" "0.12.0"
  sed -i '1 s/tools/usr/' /usr/pkg/$1/$2/usr/bin/checkmk
}

# Gawk-4.2.1
function final-gawk()
{
  sed -i 's/extras//' Makefile.in
  default "gawk" "4.2.1"
  mkdir -v /usr/share/doc/gawk-4.2.1
  cp    -v doc/{awkforai.txt,*.{eps,pdf,jpg}} /usr/share/doc/gawk-4.2.1
}

# Findutils-4.6.0
function final-findutils()
{
  sed -i 's/test-lock..EXEEXT.//' tests/Makefile.in
  sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' gl/lib/*.c
  sed -i '/unistd/a #include <sys/sysmacros.h>' gl/lib/mountlist.c
  echo "#define _IO_IN_BACKUP 0x100" >> gl/lib/stdio-impl.h
  ./configure --prefix=/usr --localstatedir=/var/lib/locate
  make
  # make check
  make DESTDIR=/usr/pkg/$1/$2 install
  mv -v /usr/pkg/$1/$2/usr/bin/find /bin
  sed -i 's|find:=${BINDIR}|find:=/bin|' /usr/pkg/$1/$2/usr/bin/updatedb
}

# Groff-1.22.4
function final-groff()
{
  PAGE=A4 ./configure --prefix=/usr
  make -j1
  make DESTDIR=/usr/pkg/$1/$2 install
}

# GRUB-2.02
function final-grub()
{
  ./configure --prefix=/usr          \
              --sbindir=/sbin        \
              --sysconfdir=/etc      \
              --disable-efiemu       \
              --disable-werror
  make
  make DESTDIR=/usr/pkg/$1/$2 install
  mkdir -pv /usr/pkg/$1/$2/usr/share/bash-completion/completions
  mv -v /usr/pkg/$1/$2/etc/bash_completion.d/grub /usr/pkg/$1/$2/usr/share/bash-completion/completions
}

# Less-530
function final-less()
{
  ./configure --prefix=/usr --sysconfdir=/etc
  make
  make DESTDIR=/usr/pkg/$1/$2 install
}

# Gzip-1.10
function final-gzip()
{
  default "gzip" "1.10"
  cp -v /usr/pkg/gzip/1.10/usr/bin/gzip /bin
}

# IPRoute2-4.20.0
function final-iproute2()
{
  sed -i /ARPD/d Makefile
  rm -fv man/man8/arpd.8
  sed -i 's/.m_ipt.o//' tc/Makefile
  make
  make DOCDIR=/usr/share/doc/iproute2-4.20.0 DESTDIR=/usr/pkg/$1/$2 install
}

# Kbd-2.0.4
function final-kbd()
{
  patch -Np1 -i ../kbd-2.0.4-backspace-1.patch
  sed -i 's/\(RESIZECONS_PROGS=\)yes/\1no/g' configure
  sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in
  PKG_CONFIG_PATH=/tools/lib/pkgconfig ./configure --prefix=/usr --disable-vlock
  make
  # make check
  make DESTDIR=/usr/pkg/$1/$2 install
  mkdir -v       /usr/pkg/$1/$2/usr/share/doc/kbd-2.0.4
  cp -R -v docs/doc/* /usr/pkg/$1/$2/usr/share/doc/kbd-2.0.4
}

# Make-4.2.1
function final-make()
{
  sed -i '211,217 d; 219,229 d; 232 d' glob/glob.c
  ./configure --prefix=/usr
  make
  # make PERL5LIB=$PWD/tests/ check
  make DESTDIR=/usr/pkg/$1/$2 install
}

# Man-DB-2.8.5
function final-mandb()
{
  ./configure --prefix=/usr                        \
              --docdir=/usr/share/doc/man-db-2.8.5 \
              --sysconfdir=/etc                    \
              --disable-setuid                     \
              --enable-cache-owner=bin             \
              --with-browser=/usr/bin/lynx         \
              --with-vgrind=/usr/bin/vgrind        \
              --with-grap=/usr/bin/grap            \
              --with-systemdtmpfilesdir=           \
              --with-systemdsystemunitdir=
  make
  # make check
  make DESTDIR=/usr/pkg/$1/$2 install
}

# Tar-1.31
function final-tar()
{
  sed -i 's/abort.*/FALLTHROUGH;/' src/extract.c
  FORCE_UNSAFE_CONFIGURE=1  \
  ./configure --prefix=/usr \
              --bindir=/bin
  make
  # make check
  make DESTDIR=/usr/pkg/$1/$2 install
  make -C doc install-html docdir=/usr/pkg/$1/$2/usr/share/doc/tar-1.31
}

# Texinfo-6.5
function final-texinfo()
{
  sed -i '5481,5485 s/({/(\\{/' tp/Texinfo/Parser.pm
  ./configure --prefix=/usr --disable-static
  make
  # make check
  make DESTDIR=/usr/pkg/$1/$2 install
  make TEXMF=/usr/pkg/$1/$2/usr/share/texmf install-tex
  pushd /usr/pkg/$1/$2/usr/share/info
  rm -v dir
  for f in *
    do install-info $f dir 2>/dev/null
  done
  popd
}

# Vim-8.1
function final-vim()
{
  echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h
  ./configure --prefix=/usr
  make
  # LANG=en_US.UTF-8 make -j1 test &> vim-test.log
  make DESTDIR=/usr/pkg/$1/$2 install
  ln -sv vim /usr/bin/vi
  for L in  /usr/pkg/$1/$2/usr/share/man/{,*/}man1/vim.1; do
      ln -sv vim.1 $(dirname $L)/vi.1
  done
  ln -sv ../vim/vim81/doc /usr/pkg/$1/$2/usr/share/doc/vim-8.1
  cat > /etc/vimrc << "EOF"
" Begin /etc/vimrc

" Ensure defaults are set before customizing settings, not after
source $VIMRUNTIME/defaults.vim
let skip_defaults_vim=1

set nocompatible
set backspace=2
set mouse=
syntax on
if (&term == "xterm") || (&term == "putty")
  set background=dark
endif

" End /etc/vimrc
EOF
}

# Procps-ng-3.3.15
function final-procps()
{
  ./configure --prefix=/usr                            \
              --exec-prefix=                           \
              --libdir=/usr/lib                        \
              --docdir=/usr/share/doc/procps-ng-3.3.15 \
              --disable-static                         \
              --disable-kill
  make
  sed -i -r 's|(pmap_initname)\\\$|\1|' testsuite/pmap.test/pmap.exp
  sed -i '/set tty/d' testsuite/pkill.test/pkill.exp
  rm testsuite/pgrep.test/pgrep.exp
  # make check
  make DESTDIR=/usr/pkg/$1/$2 install
  cp -v /usr/pkg/$1/$2/usr/lib/libprocps.so.* /lib
  ln -sfv ../../lib/$(readlink /usr/lib/libprocps.so) /usr/lib/libprocps.so
}

# Util-linux-2.33.1
function final-util()
{
  mkdir -pv /var/lib/hwclock
  rm -vf /usr/include/{blkid,libmount,uuid}
  ./configure ADJTIME_PATH=/var/lib/hwclock/adjtime   \
              --docdir=/usr/share/doc/util-linux-2.33.1 \
              --disable-chfn-chsh  \
              --disable-login      \
              --disable-nologin    \
              --disable-su         \
              --disable-setpriv    \
              --disable-runuser    \
              --disable-pylibmount \
              --disable-static     \
              --without-python     \
              --without-systemd    \
              --without-systemdsystemunitdir
  make
  # chown -Rv nobody .
  # su nobody -s /bin/bash -c "PATH=$PATH make -k check"
  make DESTDIR=/usr/pkg/$1/$2 install
}

# E2fsprogs-1.44.5
function final-e2fsprogs()
{
  mkdir -v build
  cd build
  ../configure --prefix=/usr           \
              --bindir=/bin           \
              --with-root-prefix=""   \
              --enable-elf-shlibs     \
              --disable-libblkid      \
              --disable-libuuid       \
              --disable-uuidd         \
              --disable-fsck
  make
  # make check
  make DESTDIR=/usr/pkg/$1/$2 install
  make DESTDIR=/usr/pkg/$1/$2 install-libs
  chmod -v u+w /usr/pkg/$1/$2/usr/lib/{libcom_err,libe2p,libext2fs,libss}.a
  gunzip -v /usr/pkg/$1/$2/usr/share/info/libext2fs.info.gz
  install-info --dir-file=/usr/pkg/$1/$2/usr/share/info/dir /usr/pkg/$1/$2/usr/share/info/libext2fs.info
  makeinfo -o      doc/com_err.info ../lib/et/com_err.texinfo
  install -v -m644 doc/com_err.info /usr/pkg/$1/$2/usr/share/info
  install-info --dir-file=/usr/pkg/$1/$2/usr/share/info/dir /usr/pkg/$1/$2/usr/share/info/com_err.info
}

# Sysklogd-1.5.1
function final-sysklogd()
{
  sed -i '/Error loading kernel symbols/{n;n;d}' ksym_mod.c
  sed -i 's/union wait/int/' syslogd.c
  make
  make BINDIR=/sbin install
}

# Sysvinit-2.93
function final-sysvinit()
{
  patch -Np1 -i ../sysvinit-2.93-consolidated-1.patch
  make
  make DESTDIR=/usr/pkg/$1/$2 install
}

# Eudev-3.2.7
function final-eudev()
{
  cat > config.cache << "EOF"
HAVE_BLKID=1
BLKID_LIBS="-lblkid"
BLKID_CFLAGS="-I/tools/include"
EOF
  ./configure --prefix=/usr           \
              --bindir=/sbin          \
              --sbindir=/sbin         \
              --libdir=/usr/lib       \
              --sysconfdir=/etc       \
              --libexecdir=/lib       \
              --with-rootprefix=      \
              --with-rootlibdir=/lib  \
              --enable-manpages       \
              --disable-static        \
              --config-cache
  LIBRARY_PATH=/tools/lib make
  mkdir -pv /lib/udev/rules.d
  mkdir -pv /etc/udev/rules.d
  # make LD_LIBRARY_PATH=/tools/lib check
  make LD_LIBRARY_PATH=/tools/lib DESTDIR=/usr/pkg/$1/$2 install
  tar -xvf ../udev-lfs-20171102.tar.bz2
  make -f udev-lfs-20171102/Makefile.lfs DESTDIR=/usr/pkg/$1/$2 install
  LD_LIBRARY_PATH=/tools/lib udevadm hwdb --update
}

# function final-for extracting packages, removing folders after installation etc.
# $1 archive to process
# $2 function final-for a package to run
function install_package()
{
  # Create directories in /usr/pkg
  mkdir -pv /usr/pkg/$3/$4/
  # As of now, all archives are tar based
  filefullname=$(basename -- "$1")
  foldername="${filefullname%.tar*}"
  extension="${filefullname##$foldername}"
  tar -xf $filefullname
  pushd $foldername

  # Call main configuration function
  $2 $3 $4

  # Cleanup
  popd
  rm -rf $foldername

  # Link /usr/pkg to user space
  cp -rfvs /usr/pkg/$3/$4/* /
}

install_package linux-4.20.12.tar.xz final-linux "linux" "4.20.12"
install_package man-pages-4.16.tar.xz final-manpages  "man-pages" "4.16"
install_package glibc-2.29.tar.xz final-glibc "glibc" "2.29"

# Adjust the toolchain
# TODO: Provide better logs
mv -v /tools/bin/{ld,ld-old}
mv -v /tools/$(uname -m)-pc-linux-gnu/bin/{ld,ld-old}
mv -v /tools/bin/{ld-new,ld}
ln -sv /tools/bin/ld /tools/$(uname -m)-pc-linux-gnu/bin/ld
gcc -dumpspecs | sed -e 's@/tools@@g'                   \
    -e '/\*startfile_prefix_spec:/{n;s@.*@/usr/lib/ @}' \
    -e '/\*cpp:/{n;s@$@ -isystem /usr/include@}' >      \
    `dirname $(gcc --print-libgcc-file-name)`/specs
echo 'int main(){}' > dummy.c
cc dummy.c -v -Wl,--verbose &> dummy.log
readelf -l a.out | grep ': /lib'
if [ $? -eq 1 ]; then
  echo "Linking did not work!"
  exit 1
fi
grep -o '/usr/lib.*/crt[1in].*succeeded' dummy.log
if [ $? -eq 1 ]; then
  echo "Linking did not work!"
  exit 1
fi
grep -B1 '^ /usr/include' dummy.log
if [ $? -eq 1 ]; then
  echo "Linking did not work!"
  exit 1
fi
grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g'
if [ $? -eq 1 ]; then
  echo "Linking did not work!"
  exit 1
fi
grep "/lib.*/libc.so.6 " dummy.log
if [ $? -eq 1 ]; then
  echo "Linking did not work!"
  exit 1
fi
grep found dummy.log
if [ $? -eq 1 ]; then
  echo "Linking did not work!"
  exit 1
fi
rm -v dummy.c a.out dummy.log

install_package zlib-1.2.11.tar.xz final-zlib "zlib" "1.2.11"
install_package file-5.36.tar.gz default "file" "5.36"
install_package readline-8.0.tar.gz final-readline "readline" "5.36"
install_package m4-1.4.18.tar.xz final-m4 "m4" "1.4.18"
install_package bc-1.07.1.tar.gz final-bc "bc" "1.07.1"
install_package binutils-2.32.tar.xz final-binutils "binutils" "2.32"
install_package gmp-6.1.2.tar.xz final-gmp "gmp" "6.1.2"
install_package mpfr-4.0.2.tar.xz final-mpfr "mpfr" "4.0.2"
install_package mpc-1.1.0.tar.gz final-mpc "mpc" "1.1.0" 
install_package shadow-4.6.tar.xz final-shadow "shadow" "4.6"
install_package gcc-8.2.0.tar.xz final-gcc "gcc" "8.2.0"
install_package bzip2-1.0.6.tar.gz final-bzip2 "bzip2" "1.0.6"
install_package pkg-config-0.29.2.tar.gz final-pkgconfig "pkg-config" "0.29.2" 
install_package ncurses-6.1.tar.gz final-ncurses "ncurses" "6.1"
install_package attr-2.4.48.tar.gz final-attr "attr" "2.4.48"
install_package acl-2.2.53.tar.gz final-acl "acl" "2.2.53"
install_package libcap-2.26.tar.xz final-libcap "libcap" "2.26"
install_package sed-4.7.tar.xz final-sed "sed" "4.7"
install_package psmisc-23.2.tar.xz final-psmisc "psmisc" "23.2"
install_package iana-etc-2.30.tar.bz2 final-iana "iana-etc" "2.30"
install_package bison-3.3.2.tar.xz final-bison "bison" "3.3.2"
install_package flex-2.6.4.tar.gz final-flex "flex" "2.6.4"
install_package grep-3.3.tar.xz final-grep "grep" "3.3"
install_package bash-5.0.tar.gz final-bash "bash" "5.0"
install_package libtool-2.4.6.tar.xz default "libtool" "2.4.6"
install_package gdbm-1.18.1.tar.gz final-gdbm "gdbm" "1.18.1"
install_package gperf-3.1.tar.gz final-gperf "gperf" "3.1"
install_package expat-2.2.6.tar.bz2 final-expat "expat" "2.2.6"
install_package inetutils-1.9.4.tar.xz final-inetutils "inetutils" "1.9.4"
install_package perl-5.28.1.tar.xz final-perl "perl" "5.28.1"
install_package XML-Parser-2.44.tar.gz final-xmlparser "xml-parser" "2.44"
install_package intltool-0.51.0.tar.gz final-intltool "intltool" "0.51.0"
install_package autoconf-2.69.tar.xz final-autoconf "autoconf" "2.69"
install_package automake-1.16.1.tar.xz final-automake "automake" "1.16.1"
install_package xz-5.2.4.tar.xz final-xz "xz" "5.2.4"
install_package kmod-26.tar.xz final-kmod "kmod" "26"
install_package gettext-0.19.8.1.tar.xz final-gettext "gettext" "0.19.8.1"
install_package elfutils-0.176.tar.bz2 final-libelf "elfutils" "0.176"
install_package libffi-3.2.1.tar.gz final-libffi "libffi" "3.2.1"
install_package openssl-1.1.1a.tar.gz final-openssl "openssl" "1.1.1a"
install_package Python-3.7.2.tar.xz final-python "python" "3.7.2"
install_package ninja-1.9.0.tar.gz final-ninja "ninja" "1.9.0"
install_package meson-0.49.2.tar.gz final-meson "meson" "0.49.2"
install_package coreutils-8.30.tar.xz final-coreutils "coreutils" "8.30"
install_package check-0.12.0.tar.gz final-check "check" "0.12.0"
install_package diffutils-3.7.tar.xz default "diffutils" "3.7"
install_package gawk-4.2.1.tar.xz final-gawk "gawk" "4.2.1"
install_package findutils-4.6.0.tar.gz final-findutils "findutils" "4.6.0"
install_package groff-1.22.4.tar.gz final-groff "groff" "1.22.4"
install_package grub-2.02.tar.xz final-grub "grub" "2.02"
install_package less-530.tar.gz final-less "less" "530"
install_package gzip-1.10.tar.xz final-gzip "gzip" "1.10"
install_package iproute2-4.20.0.tar.xz final-iproute2 "iproute2" "4.20.0"
install_package kbd-2.0.4.tar.xz final-kbd "kbd" "2.0.4"
install_package libpipeline-1.5.1.tar.gz default "libpipeline" "1.5.1"
install_package make-4.2.1.tar.bz2 final-make "make" "4.2.1"
install_package patch-2.7.6.tar.xz default "patch" "2.7.6"
install_package man-db-2.8.5.tar.xz final-mandb "mandb" "2.8.5"
install_package tar-1.31.tar.xz final-tar "tar" "1.31"
install_package texinfo-6.5.tar.xz final-texinfo "texinfo" "6.5"
install_package vim81.tar.bz2 final-vim "vim" "8.1"
install_package procps-ng-3.3.15.tar.xz final-procps "procps-ng" "3.3.15"
install_package util-linux-2.33.1.tar.xz final-util "util" "2.33.1"
install_package e2fsprogs-1.44.5.tar.gz final-e2fsprogs "e2fsprogs" "1.44.5"
install_package sysklogd-1.5.1.tar.gz final-sysklogd "sysklogd" "1.5.1"
install_package sysvinit-2.93.tar.xz final-sysvinit "sysvinit" "2.93"
install_package eudev-3.2.7.tar.gz final-eudev "eudev" "3.2.7"

popd

echo "Everything sucessfully installed"
# TODO: Remove debug symbols

# Clean up
rm -rf /tmp/*