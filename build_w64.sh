#!/bin/sh
set -x
set -eu
mkdir -p qemu/bin/ndebug/x86_64-w64-mingw32
cd qemu/bin/ndebug/x86_64-w64-mingw32
../../../configure --cross-prefix=x86_64-w64-mingw32- --disable-guest-agent-msi --disable-werror
make
