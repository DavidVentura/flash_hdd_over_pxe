# grub

```
# create an MBR partition table on disk
# create a '/boot' partition on disk, using a supported type like fat
# create a fs in the boot partition

# create core img
$ grub-mkimage -O i386-pc -o ./core.img -p '(hd0,msdos1)/boot/grub' biosdisk part_msdos ext2 fat exfat.mod
# write mbr to disk
$ dd if=/usr/lib/grub/i386-pc/boot.img of=qdisk.img bs=446 count=1 conv=notrunc
# write grub image to disk
$ dd if=core.img of=qdisk.img bs=512 seek=1 conv=notrunc # qemu core
# copy grub modules over
$ cp /usr/lib/grub/i386-pc/* $TARGET/boot/grub/i386-pc/
# create test grub.cfg
$ echo 'insmod echo
set timeout=5

menuentry "kernel" {
    linux   /boot/vmlinuz
    initrd  /boot/initramfs.igz
}

menuentry "test" {
    echo "hello"
}' > TARGET/boot/grub/i386-pc/grub.cfg

$ cp initramfs.igz $TARGET/boot/initramfs.igz
$ cp /boot/vmlinuz-$(uname -r) $TARGET/boot/vmlinuz
```

# compile kernel or add modules to whatever kernel you have

you can either compile a minimal kernel with the disk and network drives built
in, or add the kernel modules to the initramfs (in `/lib/modules`)

# compile busybox

```
make defconfig
make clean && make LDFLAGS=-static
```

# compile curl

```
make curl_LDFLAGS=-all-static
```

# copy DNS related libraries

```
cp /lib/x86_64-linux-gnu/libnss_files.so.2 initramfs//lib/x86_64-linux-gnu/libnss_files.so.2
cp /lib/x86_64-linux-gnu/libnss_dns.so.2 initramfs//lib/x86_64-linux-gnu/libnss_dns.so.2
```

# compile localpax-utils for ldd-tree
use ldd-tree to copy binaries that must be dynamic

# create target image somehow

.?

# dhcp

not working atm - no idea why
