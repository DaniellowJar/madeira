#!/bin/bash
# Shared environment for Madeira CI build scripts.
set -euo pipefail

export REPO="${GITHUB_WORKSPACE:?GITHUB_WORKSPACE not set}"
export TOOLCHAINS="$REPO/toolchains"
export NCPUS="${NCPUS:-$(sysctl -n hw.ncpu 2>/dev/null || echo 4)}"
export SDK="${SDK:-$(xcrun --sdk iphoneos --show-sdk-path)}"
export MACOS_SDK="${MACOS_SDK:-$(xcrun --sdk macosx --show-sdk-path)}"

# Homebrew LLVM tools (llvm-objcopy, etc.) — must NOT shadow xcrun clang,
# so add it last.
export BREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
if [ -n "$BREW_PREFIX" ] && [ -d "$BREW_PREFIX/opt/llvm/bin" ]; then
    export PATH="$BREW_PREFIX/opt/llvm/bin:$PATH"
fi
# Homebrew bison/flex (Apple's are too old)
if [ -n "$BREW_PREFIX" ] && [ -d "$BREW_PREFIX/opt/bison/bin" ]; then
    export PATH="$BREW_PREFIX/opt/bison/bin:$PATH"
fi
if [ -n "$BREW_PREFIX" ] && [ -d "$BREW_PREFIX/opt/flex/bin" ]; then
    export PATH="$BREW_PREFIX/opt/flex/bin:$PATH"
fi

MINGW_BIN="$TOOLCHAINS/llvm-mingw-20260421-ucrt-macos-universal/bin"
if [ -d "$MINGW_BIN" ]; then
    export MINGW_BIN
    export PATH="$MINGW_BIN:$PATH"
else
    export MINGW_BIN=""
fi