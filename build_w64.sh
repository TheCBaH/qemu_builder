#!/bin/sh
set -x
set -eu
# based on https://qemu.weilnetz.de/doc/BUILD.txt
mkdir -p qemu/bin/ndebug/x86_64-w64-mingw32
cd qemu/bin/ndebug/x86_64-w64-mingw32
../../../configure --cc='ccache x86_64-w64-mingw32-gcc' --cross-prefix=x86_64-w64-mingw32- --disable-guest-agent-msi --disable-werror\
 --target-list=x86_64-softmmu\
 --disable-capstone\
 --disable-guest-agent\
 --disable-gtk\
 --with-git-submodules=validate

make $@
# --enable-whpx\
release_dir=.release
rm -rf $release_dir
mkdir -p $release_dir
mv qemu-img.exe qemu-system-x86_64.exe $release_dir
x86_64-w64-mingw32-strip $release_dir/*.exe
cp -pv \
 pc-bios/bios-256k.bin\
 pc-bios/efi-virtio.rom\
 pc-bios/kvmvapic.bin\
 pc-bios/linuxboot_dma.bin\
 $release_dir

cp -pv \
 /usr/x86_64-w64-mingw32/sys-root/mingw/bin/iconv.dll\
 /usr/x86_64-w64-mingw32/sys-root/mingw/bin/zlib1.dll\
 $release_dir

for l in gio-2.0-0 glib-2.0-0 gobject-2.0-0 pixman-1-0 pcre-1 intl-8 gmodule-2.0-0 ffi-6 ; do
    cp -pv /usr/x86_64-w64-mingw32/sys-root/mingw/bin/lib${l}.dll $release_dir/
done

for l in gcc_s_seh-1 ssp-0; do
    cp -pv /usr/lib/gcc/x86_64-w64-mingw32/10-win32/lib${l}.dll $release_dir/
done

for l in winpthread-1; do
    cp -pv /usr/x86_64-w64-mingw32/lib/lib${l}.dll $release_dir/
done
