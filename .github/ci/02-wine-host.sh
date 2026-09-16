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

echo "==> [2c] generate widl headers via wine make"
# DirectWrite/Direct3D/DXGI headers the widl outputs and win32u sources
# pull in. Generate them with wine's own build system so the full widl
# dependency closure (oaidl/ocidl/objidl/urlmon/msxml/...) resolves in
# the right order. Manual widl invocations cannot do this: e.g.
# d3dcommon.idl -> ocidl.idl -> urlmon.idl -> msxml.idl needs static
# -I paths and pre-generated siblings. ole2.h/unknwn.h stay shimmed
# (static headers; make leaves them alone).
cd wine/build-macos/include
make -j"$NCPUS" \
    dxgiformat.h dcommon.h dxgitype.h d3dcommon.h \
    dxgi.h d3d10.h d3d11.h d3d12.h \
    dwrite.h dwrite_1.h dwrite_2.h dwrite_3.h \
    > include-headers.log 2>&1 \
    || { echo "widl header generation FAILED"; tail -40 include-headers.log; exit 1; }
echo "    headers: $(ls dxgiformat.h dcommon.h dxgitype.h d3dcommon.h dxgi.h d3d10.h d3d11.h d3d12.h dwrite.h dwrite_3.h 2>/dev/null | tr '\n' ' ')"
cd "$REPO"

echo "==> [2d] build-arm64ec/include -> build-macos/include"
mkdir -p wine/build-arm64ec
ln -sfn ../build-macos/include wine/build-arm64ec/include

echo "Stage 2 complete: $(ls wine/build-macos/include/config.h wine/build-macos/include/dwrite.h wine/build-macos/include/dwrite_3.h)"