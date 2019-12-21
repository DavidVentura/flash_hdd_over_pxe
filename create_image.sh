#!/bin/bash

function create_disk_image_file_and_mount_it {
    DISK=$1
    CHROOT=$2
    dd if=/dev/zero of=$DISK bs=1M count=3072
    fdisk $DISK <<EOF
o
n
p
1


w
EOF
    sudo losetup $LOOP_DEV $DISK -o $((2048*512))
    sudo mkfs.xfs $LOOP_DEV
    mkdir -p $CHROOT
    mount $LOOP_DEV $CHROOT
}

function create_installation_locally {
    CHROOT=$1
    mkdir -p $CHROOT
    # two steps as the first one populates repos, etc
    sudo yum --installroot=$CHROOT install -y http://mirror.centos.org/centos/7/os/x86_64/Packages/centos-release-7-7.1908.0.el7.centos.x86_64.rpm
    sudo yum --installroot=$CHROOT install -y yum irqbalance openssh-server rsyslog systemd sudo tar util-linux vim-minimal kernel passwd iproute cloud-utils-growpart
    
    # rsync some files to chroot instead?

    pass=$(mkpasswd --method=SHA-512 "$PLAINTEXT_PWD")
    pwdline=$(echo root:$pass:17834:0:99999:7:::)
    sudo sed -i "s|^root.*$|$pwdline|" b/etc/shadow

    echo '/dev/sda1 / xfs defaults 0 0' | sudo tee $CHROOT/etc/fstab
    cat <<EOF | sudo tee $CHROOT/opt/iniital_local_setup.sh
#!/bin/sh
growpart /dev/sda 2
xfs\_growfs /
rm -- "$0"
EOF
    echo "/bin/bash $CHROOT/opt/iniital_local_setup.sh" >> $CHROOT/etc/rc.local
    chmod +x $CHROOT/etc/rc.local
}

function install_grub_on_disk {
    DISK=$1
    TARGET=$2
    # create core img
    grub-mkimage -O i386-pc -o ./core.img -p '(hd0,msdos1)/boot/grub' biosdisk part_msdos xfs
    # write mbr to disk
    dd if=/usr/lib/grub/i386-pc/boot.img of=$DISK bs=446 count=1 conv=notrunc
    # write grub image to disk
    dd if=core.img of=$DISK bs=512 seek=1 conv=notrunc # qemu core
    # copy grub modules over
    mkdir -p $TARGET/boot/grub/i386-pc/
    cp /usr/lib/grub/i386-pc/* $TARGET/boot/grub/i386-pc/
    # create test grub.cfg
    echo 'set timeout=5
    
    menuentry "regular_startup" {
        linux   /boot/vmlinuz quiet root=/dev/sda1
        initrd  /boot/initramfs.igz
    }' | sudo tee $TARGET/boot/grub/grub.cfg
    
    cp /boot/initramfs-$(uname-r).img $TARGET/boot/initramfs.igz
    cp /boot/vmlinuz-$(uname -r) $TARGET/boot/vmlinuz

}

PLAINTEXT_PWD='on'
IMG=centos-disk.img
CHROOT=/tmp/chroot
LOOP_DEV=$(losetup -f)

create_disk_image_file_and_mount_it $IMG $CHROOT
create_installation_locally $CHROOT
install_grub_on_disk $IMG $CHROOT

losetup -d $LOOP_DEV
