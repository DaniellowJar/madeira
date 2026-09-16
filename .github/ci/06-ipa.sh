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
if [ ! -f "$VCRT/vcruntime140.dll" ]; then
    brew install sevenzip >/dev/null 2>&1 || true
    VC_REDIST_URL="${VC_REDIST_URL:-https://aka.ms/vs/17/release/vc_redist.x64.exe}"
    curl -fL "$VC_REDIST_URL" -o /tmp/vc_redist.x64.exe
    rm -rf /tmp/vcredist /tmp/vcpayload "$VCRT" && mkdir -p /tmp/vcredist /tmp/vcpayload "$VCRT"
    # The MSI payload rides as an attached CAB overlay that 7zz does not
    # reach (it only dumps the small UX streams). Carve embedded CABs by
    # MSCF magic + cbCabinet size, then unpack cab -> msi -> dlls.
    python3 - /tmp/vc_redist.x64.exe /tmp <<'EOF'
import struct, sys
exe, outdir = sys.argv[1], sys.argv[2]
d = open(exe, 'rb').read()
n = 0
i = d.find(b'MSCF')
while i != -1:
    if i + 36 <= len(d):
        sig, r1, cb, r2, coff, r3, vmin, vmaj, cfold, cfil, flags, setid, icab = \
            struct.unpack('<4sIIIIIBBHHHHH', d[i:i+36])
        if 1024 < cb <= len(d) - i and cfil < 100000:
            open(f'{outdir}/payload{n}.cab', 'wb').write(d[i:i+cb])
            print(f'carved payload{n}.cab at {i} size {cb} files {cfil}')
            n += 1
    i = d.find(b'MSCF', i + 1)
print(f'{n} cabs carved')
EOF
    for cab in /tmp/payload*.cab; do
        [ -f "$cab" ] || continue
        7zz x -y "$cab" -o/tmp/vcpayload > /dev/null 2>&1 || true
    done
    # Unpack CAB payloads (and any nested cabs) one more level. Note:
    # 7zz dumps MSI *database streams* instead of files, so MSIs need
    # msiextract (msitools) below.
    find /tmp/vcpayload -type f | while read -r a; do
        7zz x -y "$a" -o"$VCRT" > /dev/null 2>&1 || true
    done
    brew install msitools >/dev/null 2>&1 || true
    find /tmp/vcpayload /tmp/vcredist -type f | while read -r a; do
        msiextract -C "$VCRT" "$a" > /dev/null 2>&1 || true
    done
    # Classic-layout fallback (.rsrc CABINET) for older exes.
    7zz x -y /tmp/vc_redist.x64.exe -o/tmp/vcredist > /dev/null 2>&1 || true
    for cab in /tmp/vcredist/.rsrc/1033/CABINET/*.cab; do
        [ -f "$cab" ] && 7zz x -y "$cab" -o"$VCRT" > /dev/null
    done
    # Flatten in case DLLs land in subdirs.
    find "$VCRT" -mindepth 2 -name "*.dll" -exec mv {} "$VCRT/" \; 2>/dev/null || true
    [ -f "$VCRT/vcruntime140.dll" ] || { echo "vcruntime extraction yielded no DLLs"; ls "$VCRT" | head; exit 1; }
fi
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