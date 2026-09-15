#!/bin/bash
# Stage 2: Wine host build tree (wine/build-macos).
# Produces include/config.h, generated headers, host tools, and the
# widl-generated dwrite headers; wires wine/build-arm64ec/include ->
# build-macos/include (the ntdll-unix build references that path).
set -euo pipefail
source "$GITHUB_ACTION_PATH/common.sh"

cd "$REPO"

ensure_submodule wine

if [ ! -f wine/build-macos/include/config.h ]; then
    echo "==> [2a] configure wine/build-macos"
    mkdir -p wine/build-macos
    cd wine/build-macos
    export PKG_CONFIG_PATH="$BREW_PREFIX/lib/pkgconfig"
    ../configure \
        --without-x --without-freetype --without-opengl --without-vulkan \
        --without-alsa --without-cups --without-osmesa --without-dbus \
        --without-sdl --without-gstreamer --without-pulse \
        --disable-tests --disable-win16 > configure.log 2>&1 \
        || { echo "configure FAILED"; tail -40 configure.log; exit 1; }
    echo "==> [2b] build wine host tools (widl/winebuild/wrc)"
    make -j"$NCPUS" tools/widl/widl tools/winebuild/winebuild tools/wrc/wrc \
        > tools-make.log 2>&1 \
        || { echo "host tools build FAILED"; tail -60 tools-make.log; exit 1; }
else
    echo "==> wine/build-macos already configured"
fi

cd "$REPO"

echo "==> [2c] generate widl headers"
# DirectWrite/Direct3D/DXGI support headers the generated widl headers
# and win32u sources pull in. We must generate them from the .idl
# sources (as a real wine build does) because wine does not ship them
# as static headers and mingw-w64's copies assume a Win32 target.
# ole2.h and unknwn.h are provided by shims in build/ntdll-unix/shims.
for idl in dxgiformat dcommon dxgitype d3dcommon oaidl ocidl \
           dxgi d3d10 d3d11 d3d12 \
           dwrite dwrite_1 dwrite_2 dwrite_3; do
    if [ ! -f "wine/build-macos/include/$idl.h" ]; then
        wine/build-macos/tools/widl/widl -h -o "wine/build-macos/include/$idl.h" \
            "wine/include/$idl.idl" 2> "wine/build-macos/include/$idl.h.widl-err" \
            || { echo "widl $idl FAILED"; cat "wine/build-macos/include/$idl.h.widl-err"; exit 1; }
        echo "    generated include/$idl.h"
    fi
done

echo "==> [2d] build-arm64ec/include -> build-macos/include"
mkdir -p wine/build-arm64ec
ln -sfn ../build-macos/include wine/build-arm64ec/include

echo "Stage 2 complete: $(ls wine/build-macos/include/config.h wine/build-macos/include/dwrite.h wine/build-macos/include/dwrite_3.h)"