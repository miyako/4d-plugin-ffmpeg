# 4d-plugin-ffmpeg

Boilerplate for a 4D plugin that links the FFmpeg libraries (`libavformat`, `libavcodec`, `libavfilter`, `libavdevice`, `libswscale`, `libswresample`, `libpostproc`, `libavutil`) and `libx264` statically, so FFmpeg could run inside 4D instead of as a separate `ffmpeg` process. **It is a work in progress**: the plugin initialises FFmpeg when 4D loads it, but its only command, [ffmpeg Test](#ffmpeg-test), does nothing yet.

| Command | Returns | Purpose |
|---|---|---|
| [ffmpeg Test](#ffmpeg-test) | Integer | Placeholder. Shows that the plugin loads; doesn't process any media. |

**Platforms:** macOS (x86_64 only until the libraries are rebuilt, see below), Windows 64-bit

---

## Requirements & platform notes

- **Library versions.** macOS: FFmpeg `4.2.1` (`include/ffmpeg/m/libavutil/ffversion.h`), configured with `--enable-shared --enable-static --enable-libx264 --enable-gpl`. Windows: FFmpeg `4.1` built with vcpkg. The Windows import libraries are not in the repository: they're the `lib.zip` asset of the [lib-4.1](https://github.com/miyako/4d-plugin-ffmpeg/releases/tag/lib-4.1) release.
- **License.** Because the build enables `libx264` and `--enable-gpl`, the FFmpeg libraries are under the GPL version 2 or later (`FFMPEG_LICENSE` in `config.h`). A plugin that links them statically is a combined GPL work. Check that this suits your application before you distribute it.
- **Apple silicon.** The prebuilt archives in `a/` contain only an x86_64 slice, so the macOS plugin can't be built for arm64 yet. Until they're rebuilt as universal libraries, the plugin runs only in an Intel (or Rosetta) 4D.
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

The source also contains a cleanup routine adapted from FFmpeg's command-line tool (`ffmpeg_cleanup`: frees filter graphs and streams, closes input and output files). Nothing calls it yet.

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
- **The plugin doesn't load on an Apple silicon Mac.** The macOS libraries have no arm64 slice. Run 4D under Rosetta, or rebuild the libraries as universal binaries.
- **The Windows build fails at link time.** `lib/windows64/*.lib` isn't committed. Extract it from `lib.zip` on the [lib-4.1](https://github.com/miyako/4d-plugin-ffmpeg/releases/tag/lib-4.1) release.

---

## Quick reference

```4d
var $param; $result : Integer
$result:=ffmpeg Test($param)  // placeholder, does nothing
```

---


* ffmpeg Mac: ``4.2.1`` Windows (vcpkg): ~~``3.3``~~ ``4.1`` 

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
