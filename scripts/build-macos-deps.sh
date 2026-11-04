#!/bin/bash
# Builds the static libraries the Xcode project links from a/, as universal
# (arm64 + x86_64) archives, from pinned sources:
#   x264   -> a/libx264.a
#   FFmpeg -> a/libavcodec.a libavdevice.a libavfilter.a libavformat.a
#             libavutil.a libswresample.a libswscale.a, headers in include/ffmpeg/m
# FFmpeg is configured like vcpkg's port on macOS (same version as the Windows
# build): --disable-autodetect, then the Apple frameworks, plus zlib, bzip2 and
# iconv from the system, and --enable-gpl --enable-libx264 (so the libraries
# are GPL). The plugin also links -lz -lbz2 -liconv and the frameworks.
#
# usage: scripts/build-macos-deps.sh [output-dir]   (default: a/)
# WORK (default build/deps) holds the per-arch builds; a rerun reuses them.
# Needs: Xcode command line tools, git, pkg-config, nasm (x86_64 assembly).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/a}"
WORK="${WORK:-$ROOT/build/deps}"
MIN="${MACOSX_DEPLOYMENT_TARGET:-11.5}"
JOBS="$(sysctl -n hw.ncpu)"

FFMPEG_TAG=n9.0.2                                         # = vcpkg 2026.10.16 ffmpeg port
X264_SHA=b35605ace3ddf7c1a5d67a2eb553f034aef41d55         # x264 stable, = vcpkg x264 0.165.3222

FFMPEG_LIBS="libavcodec libavdevice libavfilter libavformat libavutil libswresample libswscale"

# keep Homebrew headers and libraries out of the build (pkg-config is pointed at x264 only)
unset CPATH LIBRARY_PATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH PKG_CONFIG_PATH

command -v nasm >/dev/null || { echo "nasm is needed for the x86_64 assembly (brew install nasm)" >&2; exit 1; }
command -v pkg-config >/dev/null || { echo "pkg-config is needed (brew install pkg-config)" >&2; exit 1; }

# fetch <repo url> <commit sha or tag> <dir>
fetch() {
  # skip only a completed checkout (a failed fetch leaves an empty repo behind)
  if git -C "$3" rev-parse -q --verify HEAD >/dev/null 2>&1; then
    return 0
  fi
  mkdir -p "$3"
  git -C "$3" init -q
  local i
  for i in 1 2 3; do
    git -C "$3" fetch -q --depth 1 "$1" "$2" && break
    [ "$i" = 3 ] && return 1
    echo "fetch $1 failed, retrying"; sleep 10
  done
  git -C "$3" checkout -q FETCH_HEAD
}

SRC="$WORK/src"
fetch https://github.com/FFmpeg/FFmpeg.git "refs/tags/$FFMPEG_TAG" "$SRC/ffmpeg"
fetch https://code.videolan.org/videolan/x264.git "$X264_SHA" "$SRC/x264"

build_arch() {
  local ARCH="$1" HOST
  case "$ARCH" in
    arm64)  HOST=aarch64-apple-darwin ;;
    x86_64) HOST=x86_64-apple-darwin ;;
  esac
  local D="$WORK/$ARCH"
  local FLAGS="-arch $ARCH -mmacosx-version-min=$MIN"
  local SDK; SDK="$(xcrun --sdk macosx --show-sdk-path)"
  mkdir -p "$D"

  if [ ! -f "$D/x264/lib/libx264.a" ]; then
    rm -rf "$D/x264-build"
    rsync -a --exclude .git "$SRC/x264/" "$D/x264-build/"
    (cd "$D/x264-build" &&
      CC="$(xcrun -f clang)" ./configure --host="$HOST" --prefix="$D/x264" \
        --enable-static --enable-pic --disable-cli \
        --extra-cflags="$FLAGS -isysroot $SDK" --extra-ldflags="$FLAGS -isysroot $SDK" \
        --extra-asflags="$FLAGS" >/dev/null &&
      make -j"$JOBS" >/dev/null &&
      make install-lib-static >/dev/null)
  fi

  if [ ! -f "$D/ffmpeg/lib/libavcodec.a" ]; then
    rm -rf "$D/ffmpeg-build"
    mkdir -p "$D/ffmpeg-build"
    (cd "$D/ffmpeg-build" &&
      PKG_CONFIG_LIBDIR="$D/x264/lib/pkgconfig" \
      "$SRC/ffmpeg/configure" --prefix="$D/ffmpeg" \
        --enable-cross-compile --arch="$ARCH" --target-os=darwin \
        --cc="$(xcrun -f clang)" --sysroot="$SDK" \
        --extra-cflags="$FLAGS" --extra-ldflags="$FLAGS" \
        --enable-static --disable-shared --enable-pic \
        --disable-programs --disable-doc --enable-runtime-cpudetect \
        --disable-autodetect \
        --enable-appkit --enable-avfoundation --enable-coreimage \
        --enable-audiotoolbox --enable-videotoolbox \
        --enable-zlib --enable-bzlib --enable-iconv \
        --enable-gpl --enable-libx264 --pkg-config-flags=--static >/dev/null &&
      grep -q '^#define CONFIG_LIBX264 1' config.h &&
      make -j"$JOBS" >/dev/null &&
      make install >/dev/null)
  fi
}

build_arch arm64
build_arch x86_64

mkdir -p "$OUT"
lipo -create "$WORK/arm64/x264/lib/libx264.a" "$WORK/x86_64/x264/lib/libx264.a" -output "$OUT/libx264.a"
for lib in $FFMPEG_LIBS; do
  lipo -create "$WORK/arm64/ffmpeg/lib/$lib.a" "$WORK/x86_64/ffmpeg/lib/$lib.a" -output "$OUT/$lib.a"
done

# headers: the public ones are the same on both architectures except
# libavutil/avconfig.h, which only states the endianness (little on both)
rm -rf "$ROOT/include/ffmpeg/m"
mkdir -p "$ROOT/include/ffmpeg/m"
cp -R "$WORK/arm64/ffmpeg/include/." "$ROOT/include/ffmpeg/m/"
diff -r "$WORK/arm64/ffmpeg/include" "$WORK/x86_64/ffmpeg/include"

for f in "$OUT"/libx264.a $(for l in $FFMPEG_LIBS; do echo "$OUT/$l.a"; done); do
  archs="$(lipo -archs "$f")"
  echo "$f: $archs"
  case " $archs " in *" arm64 "*) ;; *) echo "missing arm64 in $f" >&2; exit 1 ;; esac
  case " $archs " in *" x86_64 "*) ;; *) echo "missing x86_64 in $f" >&2; exit 1 ;; esac
done
