#!/bin/sh
set -x
set -eu
# based on https://qemu.weilnetz.de/doc/BUILD.txt
target=$1;shift
root=$(readlink -f $(pwd)/qemu)
mkdir -p qemu/bin/ndebug/$target
cd qemu/bin/ndebug/$target
flags=''
cflags=''
cc='cc'
_exe=''
cross=''
targets=''

qemu_root=../../..
configure=$qemu_root/configure
local=$root/local.$target
cpu_cores=$(getconf _NPROCESSORS_ONLN 2>/dev/null)

export PKG_CONFIG_PATH="$local/lib/pkgconfig"

do_meson() {(
    cd $root/../$1
    meson setup --prefix $local $static --cross-file ../cross_file_mingw_w64.txt _build
    meson compile -C _build
    meson install -C _build
)}

do_attr() {(
    cd $root/../attr
    ./autogen.sh
    ./configure --disable-nls --prefix $local CC="ccache ${cc:-gcc}"
    make -j$cpu_cores
    make install
)}

do_w64_qemu_config() {
    _exe='.exe'
    cross='x86_64-w64-mingw32-'
    cc="${cross}gcc"
    flags="$flags --cross-prefix=$cross"
    winhv=$qemu_root/../winhv
    if test -f $winhv/WinHvPlatform.h && $configure --help | grep -q 'whpx'; then
        flags="$flags --enable-whpx"
        cflags="$cflags -I$(readlink -f $winhv)"
    fi
    export LIBS="-luuid -lole32"
    static='--default-library static'
    meson_setup="--prefix $local $static --cross-file ../cross_file_mingw_w64.txt _build"
    for lib in glib pixman libslirp; do
        do_meson $lib
    done
}

case $target in
    w64-qemu)
        do_w64_qemu_config
        ;;
    static)
        do_attr
        flags="$flags --disable-stack-protector"
        flags="$flags --enable-attr"
        flags="$flags --enable-kvm"
        flags="$flags --enable-virtfs"
        flags="$flags --static"
        ;;
esac

if $configure --help | grep -q 'with-git-submodules'; then
    flags="$flags --with-git-submodules=validate"
fi

if grep -q enable-lto $configure; then
    flags="$flags --enable-lto"
    targets="qemu-img${_exe} qemu-system-x86_64${_exe}"
fi

env $configure --cc="ccache $cc $cflags"\
 --disable-capstone\
 --disable-debug-info\
 --disable-gtk\
 --disable-guest-agent-msi\
 --disable-guest-agent\
 --disable-werror\
 --target-list=x86_64-softmmu\
 $flags

make $targets $@

release_dir=.release
rm -rf $release_dir
mkdir -p $release_dir
release_dir_abs=$(readlink -f $release_dir)

do_w64_qemu_release() {

    for l in gcc_s_seh-1 ssp-0; do
        cp -pv /usr/lib/gcc/x86_64-w64-mingw32/*-win32/lib${l}.dll $release_dir/
    done

    for l in winpthread-1; do
        cp -pv /usr/x86_64-w64-mingw32/lib/lib${l}.dll $release_dir/
    done
}

case $target in
    w64-qemu)
        do_w64_qemu_release
        ;;
esac
cp -p $qemu_root/LICENSE $release_dir
mv qemu-img${_exe} $release_dir
if [ -f qemu-system-x86_64${_exe} ]; then
    mv qemu-system-x86_64${_exe} $release_dir
else
    mv x86_64-softmmu/qemu-system-x86_64${_exe} $release_dir
fi
${cross}strip $release_dir/qemu*
(
if [ ! -f pc-bios/bios-256k.bin ]; then
    cd $root
fi
cp -pv \
 pc-bios/bios-256k.bin\
 pc-bios/efi-virtio.rom\
 pc-bios/kvmvapic.bin\
 pc-bios/linuxboot_dma.bin\
 $release_dir_abs
)
