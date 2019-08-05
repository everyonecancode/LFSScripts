# LFSScripts

!WARNING!

This is still work in progress. I made this repo public righ now because it's much easier to download git repository in VM environment than setting up shared folders with Live CD VM and host system (yes, I am lazy).

Bunch of scripts created for "quickly" building a LFS machine. This has been created with virtual machine in mind, with a single partition created, so not really an optimal solution for main personal machine, but for fun with kernel and system configuration. It works when run on Debian Live CD, so we can run VM, launch the CD, create and mount drive and just run the scripts.

All build commands and version-check.sh script has been copied from LFS site, http://www.linuxfromscratch.org. Big shoutout to them, without them this scripts would have either never existed or it would take a much longer to complete those scripts. 

Usage:
1. Format drive (usally /dev/sda) into single partition and mount it to /mnt/lfs
2. Run version-check.sh to see if our system satisfies the requirements
3. Run ./lfs-install.sh AS ROOT!
4. Go for a walk, make some tea, learn a new language or start a family, because building all this software takes a LOT of time.
5. Enjoy your new hacky system.

.... or not. As of now those scripts focus on most annoying part of whole LFS creation process, which is building all the software. Users are not created, grub is not installed, no package managemenet system is in place here. But hey, it's "run and forget" software installation script, which is nice.

## About License
Just use it and don't hurt yourself. I am not responsible for any harm that may come your way after using those scripts, including system crash, system unusability, monitor flickering, AI uprising and any other. You are on your own.
However, as I just copied most code from LFS guys, I am not uploading any license or requesting that my name should be put in any of this code version. They are the ones that you should worship for figuring out all the configuration flags needed in the builds.
