all: vm
	:

initramfs.igz: initramfs/init
	cd initramfs/; find . | cpio -H newc -o  | gzip -1 > ../initramfs.igz

.PHONY: vm
vm: initramfs.igz
	sudo kvm -display gtk -kernel /boot/vmlinuz-4.15.7-custom  -initrd initramfs.igz  -append "quiet disk=/dev/sda root=/dev/sda1 init=/my_init"  -m 512 -cpu host -device e1000,netdev=net0,mac=DE:AD:BE:EF:88:39 -netdev tap,id=net0  -drive file=qemu.img,format=raw

.PHONY: vm_disk
vm_disk:
	dd if=/dev/zero of=qemu.img bs=1M count=64 >/dev/null
