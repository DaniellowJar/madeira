#!/bin/bash
# Stage 5: native iOS unix-side static libraries that are NOT committed:
#   app/Madeira/libntdll_unix.a      (wine ntdll + crypto/net/dwrite unixlibs)
#   app/Madeira/libwin32u_unix.a     (wine win32u + merged freetype)
#   app/Madeira/libwineserver.a      (wineserver-as-thread, symbol-renamed)
#   app/Madeira/libdxmt_combined.a   (DXMT unix side + airconv + LLVM)
set -euo pipefail
source "$GITHUB_ACTION_PATH/common.sh"

cd "$REPO"

for sub in research/dxmt; do
    if [ ! -d "$sub/.git" ]; then
        git submodule update --init --depth 100 "$sub"
    fi
done

echo "==> [5a] ntdll-unix"
bash build/ntdll-unix/build.sh
file app/Madeira/libntdll_unix.a

echo "==> [5b] win32u-unix"
bash build/win32u-unix/build.sh
file app/Madeira/libwin32u_unix.a

echo "==> [5c] wineserver (build base archive from wine/server, then patch)"
bash "$GITHUB_ACTION_PATH/build-wineserver-base.sh"
bash build/wineserver/build.sh all
file app/Madeira/libwineserver.a

echo "==> [5d] dxmt-ios unix side + LLVM combine"
bash build/dxmt-ios/build.sh
cd build/dxmt-ios
rm -f libdxmt_combined.a
xcrun -sdk iphoneos libtool -static -o libdxmt_combined.a \
    obj/*.o ../../toolchains/llvm-ios-build/lib/*.a
cp libdxmt_combined.a ../../app/Madeira/
cd "$REPO"
file app/Madeira/libdxmt_combined.a

echo "Stage 5 complete."
ls -la app/Madeira/libntdll_unix.a app/Madeira/libwin32u_unix.a \
       app/Madeira/libwineserver.a app/Madeira/libdxmt_combined.a