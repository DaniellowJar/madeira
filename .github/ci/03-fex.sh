#!/bin/bash
# Stage 3: FEX-Emu iOS static libraries (FEX/build-ios).
# Produces the 7 archives the Xcode project links:
#   libFEXCore.a libFEXCore_Base.a libJemallocLibs.a
#   libfmt.a libcephes_128bit.a libxxhash.a libsoftfloat_3e.a
set -euo pipefail
source "$GITHUB_ACTION_PATH/common.sh"

cd "$REPO"

ensure_submodule FEX
if [ ! -d FEX/External/range-v3/.git ]; then
    git -C FEX submodule update --init --recursive --depth 100 \
        > FEX/submodules.log 2>&1 || { tail -30 FEX/submodules.log; exit 1; }
fi

if [ ! -f FEX/build-ios/FEXCore/Source/libFEXCore.a ]; then
    echo "==> [3a] configure FEX for iOS"
    rm -rf FEX/build-ios
    cmake -S FEX -B FEX/build-ios -G Ninja \
        -DCMAKE_SYSTEM_NAME=iOS \
        -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
        -DCMAKE_OSX_SYSROOT=iphoneos \
        -DBUILD_TESTING=OFF \
        -DTUNE_CPU=generic -DTUNE_ARCH=generic \
        -DFEX_IOS_HOST_BUILD=ON \
        -DCMAKE_C_FLAGS=-DFEX_IOS_HOST \
        -DCMAKE_CXX_FLAGS=-DFEX_IOS_HOST \
        -DCMAKE_ASM_FLAGS=-DFEX_IOS_HOST \
        -DCMAKE_OSX_ARCHITECTURES=arm64 \
        -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_TESTS=OFF -DBUILD_BENCHMARKS=OFF \
        -DENABLE_LTO=OFF \
        -DCMAKE_CROSSCOMPILING=ON \
        > FEX/cmake-ios.log 2>&1 \
        || { echo "FEX cmake FAILED"; tail -60 FEX/cmake-ios.log; exit 1; }
    echo "==> [3b] build FEX"
    cmake --build FEX/build-ios -j "$NCPUS" > FEX/build-ios.log 2>&1 \
        || { echo "FEX build FAILED"; tail -80 FEX/build-ios.log; exit 1; }
fi

echo "==> verifying FEX archives"
REQUIRED=(
    FEX/build-ios/FEXCore/Source/libFEXCore.a
    FEX/build-ios/FEXCore/Source/libFEXCore_Base.a
    FEX/build-ios/FEXCore/Source/libJemallocLibs.a
    FEX/build-ios/External/fmt/libfmt.a
    FEX/build-ios/External/cephes/libcephes_128bit.a
    FEX/build-ios/External/xxhash/cmake_unofficial/libxxhash.a
    FEX/build-ios/External/SoftFloat-3e/libsoftfloat_3e.a
)
ok=1
for f in "${REQUIRED[@]}"; do
    if [ -f "$f" ]; then
        echo "    OK $f ($(du -h "$f" | cut -f1))"
    else
        echo "    MISSING $f"
        ok=0
    fi
done
[ "$ok" = 1 ] || { echo "FEX build incomplete"; exit 1; }
echo "Stage 3 complete."