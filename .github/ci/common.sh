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

# ensure_submodule <path>: initialize a submodule even when a CI cache has
# already restored files into its (empty-of-source) directory. Those files
# (build caches) are moved aside, the submodule is cloned, then moved back.
ensure_submodule() {
    local path=$1
    local tmp
    if [ -e "$path/.git" ]; then
        git submodule update --depth 100 "$path" 2>/dev/null || true
        return
    fi
    if [ -n "$(ls -A "$path" 2>/dev/null)" ]; then
        tmp="$(mktemp -d "$REPO/.ensub.XXXXXX")"
        mv "$path" "$tmp/cached"
        git submodule update --init --depth 100 "$path"
        if [ -d "$tmp/cached" ]; then
            for d in "$tmp"/cached/*; do
                [ -e "$d" ] && mv "$d" "$path"/
            done
        fi
        rm -rf "$tmp"
    else
        git submodule update --init --depth 100 "$path"
    fi
}