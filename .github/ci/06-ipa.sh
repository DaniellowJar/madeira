#!/bin/bash
# Stage 6: assemble the app, package Madeira.ipa, publish a release.
# Uses committed artifacts + cache-restored FEX libs + stage-5 unixlibs.
set -euo pipefail
source "$GITHUB_ACTION_PATH/common.sh"

cd "$REPO"

echo "==> [6a] MSVC runtime DLLs"
VCRT="$REPO/app/Madeira/x86_64-vcruntime"
if [ ! -f "$VCRT/vcruntime140.dll" ]; then
    brew install sevenzip >/dev/null 2>&1 || true
    # Pinned 14.38 and aka.ms latest both ship a numbered-stream bundle
    # layout whose MSI payload 7zz cannot reach. VS 2019 (14.29) and
    # VS 2017 (14.16) redists predate that repackaging and keep the
    # classic .rsrc/1033/CABINET layout. Try each in turn; override the
    # whole list via VC_REDIST_URLS env (space-separated) if needed.
    VC_REDIST_URLS="${VC_REDIST_URLS:-https://aka.ms/vs/16/release/vc_redist.x64.exe https://aka.ms/vs/15/release/vc_redist.x64.exe}"
    rm -rf "$VCRT"
    for VC_URL in $VC_REDIST_URLS; do
        echo "    trying $VC_URL"
        curl -fL "$VC_URL" -o /tmp/vc_redist.x64.exe || continue
        rm -rf /tmp/vcredist && mkdir -p /tmp/vcredist
        7zz x -y /tmp/vc_redist.x64.exe -o/tmp/vcredist > /dev/null 2>&1 || continue
        mkdir -p "$VCRT"
        for cab in /tmp/vcredist/.rsrc/1033/CABINET/*.cab; do
            [ -f "$cab" ] && 7zz x -y "$cab" -o"$VCRT" > /dev/null
        done
        # Flatten in case DLLs land in subdirs.
        find "$VCRT" -mindepth 2 -name "*.dll" -exec mv {} "$VCRT/" \; 2>/dev/null || true
        [ -f "$VCRT/vcruntime140.dll" ] && break
    done
    [ -f "$VCRT/vcruntime140.dll" ] || { echo "vcruntime extraction yielded no DLLs"; exit 1; }
fi
echo "    vcruntime DLLs: $(ls "$VCRT"/*.dll 2>/dev/null | wc -l | tr -d ' ') of 12"
REQUIRED_DLLS="concrt140.dll msvcp140.dll msvcp140_1.dll msvcp140_2.dll
               msvcp140_atomic_wait.dll msvcp140_codecvt_ids.dll
               vcamp140.dll vccorlib140.dll vcomp140.dll vcruntime140.dll
               vcruntime140_1.dll vcruntime140_threads.dll"
missing=""
for d in $REQUIRED_DLLS; do
    [ -f "$VCRT/$d" ] || missing="$missing $d"
done
[ -z "$missing" ] || { echo "missing vcruntime DLLs:$missing"; exit 1; }
echo "    all 12 MSVC runtime DLLs present (unsigned .ipa -> resigning needed on device)"

echo "==> [6b] verify linked libraries are in place"
REQUIRED_LIBS=(
    FEX/build-ios/FEXCore/Source/libFEXCore.a
    FEX/build-ios/FEXCore/Source/libFEXCore_Base.a
    FEX/build-ios/FEXCore/Source/libJemallocLibs.a
    FEX/build-ios/External/fmt/libfmt.a
    FEX/build-ios/External/cephes/libcephes_128bit.a
    FEX/build-ios/External/xxhash/cmake_unofficial/libxxhash.a
    FEX/build-ios/External/SoftFloat-3e/libsoftfloat_3e.a
    app/Madeira/libntdll_unix.a
    app/Madeira/libwin32u_unix.a
    app/Madeira/libwineserver.a
    app/Madeira/libdxmt_combined.a
    app/Madeira/libgnutls.a
    app/Madeira/libhogweed.a
    app/Madeira/libnettle.a
    app/Madeira/libgmp.a
)
for lib in "${REQUIRED_LIBS[@]}"; do
    if [ -f "$lib" ]; then echo "    OK $lib"; else echo "    MISSING $lib"; exit 1; fi
done
# Xcode links FEX libs by path under FEX/build-ios; the FEXCore_Source libs
# live there after cache restore.
echo "==> [6c] xcodebuild Madeira.app"
SDKVER=$(xcodebuild -showsdks 2>/dev/null | awk '/iphoneos/{print $NF}' | head -1)
echo "    iphoneos SDK: $SDKVER"
xcodebuild -project app/Madeira.xcodeproj -scheme Madeira \
    -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
    -derivedDataPath build/derived \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
    build > build/xcodebuild.log 2>&1 \
    || { echo "xcodebuild FAILED"; tail -100 build/xcodebuild.log; exit 1; }

APP_DIR="build/derived/Build/Products/Release-iphoneos"
APP="$APP_DIR/Madeira.app"
[ -d "$APP" ] || { echo "Madeira.app not produced"; exit 1; }
echo "    Madeira.app: $(du -sh "$APP" | cut -f1)"

echo "==> [6d] package Madeira.ipa"
rm -rf build/ipa && mkdir -p build/ipa/Payload
cp -R "$APP" build/ipa/Payload/Madeira.app
cd build/ipa
zip -qry -9 ../../Madeira.ipa Payload
cd "$REPO"
echo "    Madeira.ipa: $(du -h Madeira.ipa | cut -f1)"

echo "==> [6e] publish release"
TAG="ci-$(date +%Y%m%d-%H%M%S)"
gh release create "$TAG" Madeira.ipa \
    --repo "$GITHUB_REPOSITORY" \
    --title "Madeira CI build $TAG" \
    --notes "CI build of Madeira. Unsigned IPA — sign with your Apple ID (StikDebug/AltStore) and sideload." \
    > /dev/null
echo "release: https://github.com/$GITHUB_REPOSITORY/releases/tag/$TAG"

echo "Stage 6 complete."