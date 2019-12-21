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
