#!/bin/bash

set -e
function validate_bootstrapping_system {
    echo + Validating bootstrapping system
    command -v python >/dev/null || (echo "+ python not available!" && exit 1)
    command -v grub2-mkimage >/dev/null || (echo "+ grub2-mkimage not available!" && exit 1)
    [ -d /usr/lib/grub/i386-pc/ ] || (echo "+ /usr/lib/grub/i386-pc/ does not exist" && exit 1)
}

function cleanup {
    losetup -l | grep -q $LOOP_DEV && (
        echo + Unmonting chroot
        sudo umount $CHROOT
        echo + Unmonting loopback devices
        sudo losetup -d $LOOP_DEV
    )
}

function create_disk_image_file_and_mount_it {
    DISK=$1
    CHROOT=$2
    SIZE_IN_GB=3
    # FIXME

    echo + Creating disk at $DISK of size $SIZE_IN_GB GB
    dd if=/dev/zero of=$DISK bs=1G count=$SIZE_IN_GB 2>/dev/null
    echo + Partitioning disk
    fdisk $DISK <<EOF 2>/dev/null >&2
o
n
p
1


w
EOF
    sudo losetup $LOOP_DEV $DISK -o $((2048*512))
    echo + Creating filesystem
    sudo mkfs.xfs -q $LOOP_DEV
    mkdir -p $CHROOT
    echo + Mounting the disk $DISK on $CHROOT
    sudo mount $LOOP_DEV $CHROOT
}

function create_installation_locally {
    CHROOT=$1
    [ -d $CHROOT ] || (echo $CHROOT does not exist! && exit 1)
    # two steps as the first one populates repos, etc
    echo + Running system bootstrap in chroot
    sudo yum -q --installroot=$CHROOT install -y http://mirror.centos.org/centos/7/os/x86_64/Packages/centos-release-7-7.1908.0.el7.centos.x86_64.rpm
    echo + Running yum install of system utilities
    # kernel not installed ? FIXME
    sudo yum -q --installroot=$CHROOT install -y yum irqbalance openssh-server rsyslog systemd sudo tar util-linux vim-minimal passwd iproute cloud-utils-growpart
    echo + Setting up password and copying some scripts
    # rsync some files to chroot instead?

    pass=$(python -c "import crypt; print(crypt.crypt('$PLAINTEXT_PWD', crypt.mksalt(crypt.METHOD_SHA512)))")
    pwdline="root:$pass:17834:0:99999:7:::"
    echo + Setting root password
    sudo sed -i "s|^root.*$|$pwdline|" $CHROOT/etc/shadow

    echo '/dev/sda1 / xfs defaults 0 0' | sudo tee $CHROOT/etc/fstab >/dev/null
    cat <<EOF | sudo tee $CHROOT/opt/initial_local_setup.sh >/dev/null
#!/bin/sh
echo growing disk and fs if possible
growpart /dev/sda 1 && xfs_growfs /
deleting myself
rm -- "\$0"
deleting myself from /etc/rc.local
sed -i '/\$0/d' /etc/rc.local

EOF
    echo "/bin/bash /opt/initial_local_setup.sh >/var/log/initial.log 2>&1" | sudo tee -a $CHROOT/etc/rc.local >/dev/null
    sudo chmod +x $CHROOT/etc/rc.local
}

function install_grub_on_disk {
    DISK=$1
    TARGET=$2
    echo + Creating grub core image
    grub2-mkimage -O i386-pc -o ./core.img -p '(hd0,msdos1)/boot/grub' biosdisk part_msdos xfs
    echo + Writing MBR to disk
    dd if=/usr/lib/grub/i386-pc/boot.img of=$DISK bs=446 count=1 conv=notrunc 2>/dev/null
    echo + Writing grub image to disk
    dd if=core.img of=$DISK bs=512 seek=1 conv=notrunc 2>/dev/null
    echo + Copying grub modules to disk
    sudo mkdir -p $TARGET/boot/grub/i386-pc/
    sudo cp /usr/lib/grub/i386-pc/* $TARGET/boot/grub/i386-pc/
    echo + Writing grub config to target FS
    echo 'set timeout=5
    
    menuentry "regular_startup" {
        linux   /boot/vmlinuz quiet root=/dev/sda1
        initrd  /boot/initramfs.igz
    }' | sudo tee $TARGET/boot/grub/grub.cfg >/dev/null
    
    echo + Copying LOCAL kernel and initramfs to target machine
    sudo cp /boot/initramfs-$(uname -r).img $TARGET/boot/initramfs.igz
    sudo cp /boot/vmlinuz-$(uname -r) $TARGET/boot/vmlinuz
}

PLAINTEXT_PWD='on'
IMG=centos-disk.img
CHROOT=/tmp/chroot
LOOP_DEV=$(losetup -f)

validate_bootstrapping_system

trap cleanup EXIT
create_disk_image_file_and_mount_it $IMG $CHROOT
create_installation_locally $CHROOT
install_grub_on_disk $IMG $CHROOT

echo "+ Everything finished successfully"
