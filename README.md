# centos image creation

## create the disk
```
# note this is 3GB.. depending on what you install you want to make this larger
dd if=/dev/zero of=centos-disk.img bs=1M count=3072
fdisk centos-disk.img <<EOF
o
n
p
1


w
EOF
sudo losetup /dev/loop0 centos-disk.img -o $((2048*512))
sudo mkfs.xfs /dev/loop0

```

## install centos to the disk
```
CHROOT=/tmp/chroot
mkdir -p $CHROOT
wget http://mirror.centos.org/centos/7/os/x86_64/Packages/centos-release-7-7.1908.0.el7.centos.x86_64.rpm
sudo rpm --root=$CHROOT --nodeps -i centos-release-7-7.1908.0.el7.centos.x86_64.rpm
sudo yum --installroot=$CHROOT install -y yum irqbalance openssh-server rsyslog systemd sudo tar util-linux vim-minimal kernel passwd iproute
cp /etc/os-release $CHROOT/etc/os-release

plaintext_pwd='on'
pass=$(mkpasswd --method=SHA-512 "$plaintext_pwd")
pwdline=$(echo root:$pass:17834:0:99999:7:::)
sudo sed -i "s|^root.*$|$pwdline|" b/etc/shadow

echo '/dev/sda1 / xfs defaults 0 0' | sudo tee $CHROOT/etc/fstab


```

## install grub to the disk

```
# create an MBR partition table on disk
# create a '/boot' partition on disk, using a supported type like fat
# create a fs in the boot partition

# create core img
$ grub-mkimage -O i386-pc -o ./core.img -p '(hd0,msdos1)/boot/grub' biosdisk part_msdos xfs
# write mbr to disk
$ dd if=/usr/lib/grub/i386-pc/boot.img of=centos-disk.img bs=446 count=1 conv=notrunc
# write grub image to disk
$ dd if=core.img of=centos-disk.img bs=512 seek=1 conv=notrunc # qemu core
# copy grub modules over
$ mkdir -p $TARGET/boot/grub/i386-pc/
$ cp /usr/lib/grub/i386-pc/* $TARGET/boot/grub/i386-pc/
# create test grub.cfg
$ echo 'insmod echo
set timeout=5

menuentry "kernel" {
    linux   /boot/vmlinuz quiet root=/dev/sda1
    initrd  /boot/initramfs.igz
}

menuentry "test" {
    echo "hello"
}' | sudo tee TARGET/boot/grub/grub.cfg

$ cp /boot/initramfs-$(uname-r).img $TARGET/boot/initramfs.igz
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
