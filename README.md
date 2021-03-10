# LFSScripts

!WARNING!

This is still work in progress. I made this repo public righ now because it's much easier to download git repository in VM environment than setting up shared folders with Live CD VM and host system (yes, I am lazy).

Bunch of scripts created for "quickly" building a LFS machine. This has been created with virtual machine in mind, with a single partition created, so not really an optimal solution for main personal machine, but for fun with kernel and system configuration. It works when run on Debian Live CD, so we can run VM, launch the CD, create and mount drive and just run the scripts.

All build commands and version-check.sh script has been copied from LFS site, http://www.linuxfromscratch.org. Big shoutout to them, without them these scripts would have either never existed or it would take a much longer to complete those scripts. 

## Options
--drive | -d - drive, where grub will be installed (i.ex /dev/sda).  
--number | -n - boot partition number. This will be used in grub.cfg.

!WARNING!
As of now, no script for changing "sdx" to "hdx" in generating menuconfig is present. If you choose any other partition than /dev/sda, you will need to change "set root=" line in grub.cfg manually. Just to make sure, you get it: "sda" is "hd0", "sdb" is "hd1", "sdc" is "hd2" and so on. So, for example, if your boot partition is /dev/sdc3, your "set root" line will look like this:
```bash
set root=(hd2,3)
```

## Usage
1. Format drives however you like and mount root partition on /mnt/lfs. Mount rest of partition there to create any folder configuration you desire. I.e. format /dev/sda into one partition and mount it into /mnt. Or mount /dev/sda into root and boot partitions and mount them to /mnt/lfs and /mnt/lfs/boot.
2. Run version-check.sh to see if our system satisfies the requirements
3. Run ./lfs-install.sh --drive /dev/sdx --number 1 (for example: "./lfs-install.sh --drive /dev/sda --number 1" ) AS ROOT!
4. Go for a walk, make some tea, learn a new language or start a family, because building all this software takes a LOT of time.
5. Create root password by chrooting into environment and running "passwd root" command or by running "passwd -d root", which deletes password, allowing you to log into system without password, and the set it by using passwd command (I'm showing this option only because sometimes chroot environment acts a little weird, not allowing user to set the password). 
6. Enjoy your new hacky system....

.... or not. As of now, those scripts focus mostly on most annoying part of whole LFS creation process, which is building all the software.

## Package system
There is no preinstalled package system, such as aptitude or rpm manager. Software is installed using link-based package management, meaning that every program is installed into /usr/pkg/\<package-name>/\<package-version>/ and then root directory is populated with symbolic links. This should prove to be useful when upgrading the package (just download the source, "./configure --prefix=/usr", "make" it into new /pkg/ folder \["make DESTDIR=/usr/pkg/\<package-name>/\<package-version>/ install" usually works], and then issue command:
```bash
cp -rfvs /usr/pkg/<package-name>/<package-version>/ /
```
This will create symbolic links for you package. Be careful with "make install", though - some software providers use another variables to store installation directory, "prefix" for example :).

## About License
Just use it and don't hurt yourself. I am not responsible for any harm that may come your way after using those scripts, including system crash, system unusability, monitor flickering, AI uprising and any other. You are on your own.
However, as I just copied most code from LFS guys, I am not uploading any license or requesting that my name should be put in any fork or copy of this repo. They are the ones that you should worship for figuring out all the configuration flags needed in the builds.
