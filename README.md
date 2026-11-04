# 4d-plugin-ffmpeg

Boilerplate for a 4D plugin that links the FFmpeg libraries (`libavformat`, `libavcodec`, `libavfilter`, `libavdevice`, `libswscale`, `libswresample`, `libavutil`) and `libx264` statically, so FFmpeg could run inside 4D instead of as a separate `ffmpeg` process. **It is a work in progress**: the plugin initialises FFmpeg when 4D loads it, but its only command, [ffmpeg Test](#ffmpeg-test), does nothing yet.

| Command | Returns | Purpose |
|---|---|---|
| [ffmpeg Test](#ffmpeg-test) | Integer | Placeholder. Shows that the plugin loads; doesn't process any media. |

**Platforms:** macOS (universal arm64 + x86_64, macOS 11.5 or later), Windows 64-bit

---

## Requirements & platform notes

- **Library versions.** FFmpeg `9.0.2` and x264 `0.165.3222` (stable branch, commit `b35605ac`) on both platforms, linked statically (current source, 2026; before that macOS had FFmpeg 4.2.1 for Intel only, and Windows FFmpeg 4.1 from vcpkg). The libraries are not in the repository: `scripts/build-macos-deps.sh` and `scripts/build-windows-deps.ps1` build them, and the CI and release workflows run them (see [Building](#building)). libpostproc is no longer linked: FFmpeg 8 removed it.
- **What FFmpeg is built with.** On macOS: `--disable-autodetect`, then AppKit, AVFoundation, Core Image, AudioToolbox and VideoToolbox, plus the system zlib, bzip2 and iconv. On Windows, the vcpkg port's defaults (Media Foundation, DXVA2, D3D11VA, D3D12VA) with the `zlib`, `bzip2` and `iconv` features. There is no TLS library, so `https://` inputs are not supported.
- **License.** The build enables `libx264` with `--enable-gpl`, so the FFmpeg libraries are under the GPL version 2 or later. A plugin that links them statically is a combined GPL work. Check that this suits your application before you distribute it.
- **What happens at load time.** When 4D loads the plugin, it calls `avdevice_register_all()` and `avformat_network_init()`. When 4D unloads it, it calls `avformat_network_deinit()` (added in the 2026 review; before that, nothing was released at exit).
- **Thread safety.** The manifest declares [ffmpeg Test](#ffmpeg-test) thread safe, so it can be called from a preemptive process.

---

## ffmpeg Test

### Syntax

```
ffmpeg Test ( param ) -> Function result
```

| Parameter | Type | Description |
|---|---|---|
| `param` | Integer | Declared in the manifest (`&J`) but never read by the command. |
| Function result | Integer | Never set by the command. Expect `0`. |

### Description

`ffmpeg Test` is the placeholder left by the plugin template. It reads two timestamps (wall clock, user and system CPU time) and discards them. It doesn't open a file, doesn't transcode anything, doesn't set its result, and doesn't raise a 4D error. Use it only to check that the plugin is installed and loaded.

Release 1.0 also contained a cleanup routine and data structures copied from FFmpeg 4.2's command-line tool (`ffmpeg_cleanup`). Nothing called them, and they don't compile against current FFmpeg, so they were removed with the move to FFmpeg 9 (2026).

### Example

From the plugin's own test method (`test/Project/Sources/Methods/TEST.4dm`):

```4d
ffmpeg Test 
```

Reading the result (inferred from the manifest; the value isn't set by the plugin):

```4d
var $param; $result : Integer
$result:=ffmpeg Test($param)
```

---

## Error handling & troubleshooting

- **The command does nothing.** [ffmpeg Test](#ffmpeg-test) neither reads its parameter nor sets its result. The plugin can't convert or inspect media files yet.
- **The plugin doesn't load on an Apple silicon Mac (release 1.0).** Its libraries had no arm64 slice. The current source builds universal libraries.
- **The build fails with missing `a/*.a` or `lib/windows64/*.lib`.** Run the build script for your platform first (see [Building](#building)).

---

## Quick reference

```4d
var $param; $result : Integer
$result:=ffmpeg Test($param)  // placeholder, does nothing
```

---

## Building

- **macOS**: `scripts/build-macos-deps.sh` builds x264 and FFmpeg once per architecture and merges them into universal archives in `a/` (`libavcodec.a`, `libavdevice.a`, `libavfilter.a`, `libavformat.a`, `libavutil.a`, `libswresample.a`, `libswscale.a`, `libx264.a`), and copies the FFmpeg headers to `include/ffmpeg/m/`. It needs the Xcode command line tools and `brew install nasm pkg-config`. The Xcode project then links those archives plus `-lz -lbz2 -liconv` and the Apple frameworks.
- **Windows**: `scripts\build-windows-deps.ps1` installs `ffmpeg[gpl,x264,zlib,bzip2,iconv]` for `x64-windows-static` with vcpkg pinned to release 2026.10.16, and copies the libraries to `lib\windows64\` and the headers to `include\ffmpeg\w\`. It needs Visual Studio 2022 with the C++ tools; vcpkg downloads the rest (MSYS2, NASM).

`.github/workflows/ci.yml` runs both scripts and builds the plugin, unsigned, on every push; `release.yml` does the same before signing. Both cache the libraries under the hash of the script, so changing a pinned version rebuilds them.

---

Original notes (2019): ffmpeg Mac: ``4.2.1`` Windows (vcpkg): ~~``3.3``~~ ``4.1``

## Why build a plugin?

[``ffmpeg``](https://ffmpeg.zeranoe.com/builds/) and [``mp4box``](https://gpac.wp.imt.fr/2015/07/29/gpac-build-mp4box-only-all-platforms/) are essential tools for creating video contents for streaming.

c.f. [Making Your Own Simple MPEG-DASH Server](https://www.instructables.com/id/Making-Your-Own-Simple-DASH-MPEG-Server-Windows-10/)

With 4D, static builds of [``ffmpeg``](https://ffmpeg.zeranoe.com/builds/) and [``mp4box``](https://gpac.wp.imt.fr/2015/07/29/gpac-build-mp4box-only-all-platforms/) can be distributed with the application, invoked via ``LAUNCH EXTERNAL PROCESS``. That option is explored [here](https://github.com/miyako/4d-video-server-example). These command line tools are highly interactive, which is not ideal for ``LAUNCH EXTERNAL PROCESS``, especially on Windows where ``StdIn`` ``stdOut`` ``stdErr``  could overwhelm the application to the point of suffocation. Disabling progress and/or logs is one way to deal with it, but the lack of feedback can itself be an issue. Same with ``LAUNCH EXTERNAL PROCESS`` in asynchronous mode. The command is now thread safe and returns a ``pid``, so there are ways to workaround the pipe issue. Another possibility is to devep a lean plugin version of the ``ffmpeg`` and ``mp4box`` tools with callbacks.

## Build notes

If the plugin is C++, surround the include headers:

```c
#ifdef __cplusplus
extern "C" {
#endif

  //headers

#ifdef __cplusplus
}
#endif
```

Build ``libx264`` first, then build ``ffmpeg``

```sh
./configure --enable-shared --enable-static --enable-libx264 --enable-gpl 
```

Some headers, such as ``config.h`` need to be copied to project after the ``configure``.

Also ``libavutil/thread.h`` ``libavutil/internal.h`` ``libavutil/timer.h`` ``libavutil/x86`` ``libavutil/libm.h``
