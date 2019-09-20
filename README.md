# 4d-plugin-ffmpeg
boilerplate project for static ffmpeg plugin edition

### **work in progress** 

* ffmpeg Mac: ``4.2.1`` Windows: ``3.3`` TODO: update vcpkg to ``4.1`` 

#### Why build a plugin?

[``ffmpeg``](https://ffmpeg.zeranoe.com/builds/) and [``mp4box``](https://gpac.wp.imt.fr/2015/07/29/gpac-build-mp4box-only-all-platforms/) are essential tools for creating video contents for streaming.

c.f. [Making Your Own Simple MPEG-DASH Server](https://www.instructables.com/id/Making-Your-Own-Simple-DASH-MPEG-Server-Windows-10/)

With 4D, static builds of [``ffmpeg``](https://ffmpeg.zeranoe.com/builds/) and [``mp4box``](https://gpac.wp.imt.fr/2015/07/29/gpac-build-mp4box-only-all-platforms/) can be distributed with the application, invoked via ``LAUNCH EXTERNAL PROCESS``. That option is explored [here](https://github.com/miyako/4d-video-server-example). These command line tools are highly interactive, which is not ideal for ``LAUNCH EXTERNAL PROCESS``, especially on Windows where ``StdIn`` ``stdOut`` ``stdErr``  could overwhelm the application to the point of suffocation. Disabling progress and/or logs is one way to deal with it, but the lack of feedback can itself be an issue. Same with ``LAUNCH EXTERNAL PROCESS`` in asynchronous mode. The command is now thread safe and returns a ``pid``, so there are ways to workaround the pipe issue. Another possibility is to devep a lean plugin version of the ``ffmpeg`` and ``mp4box`` tools with callbacks.

#### Notes 

If the plugin is C++, surround the include headers:

``c
#ifdef __cplusplus
extern "C" {
#endif

  //headers

#ifdef __cplusplus
}
#endif
``

Build ``libx264`` first, then build ``ffmpeg``

```sh
./configure --enable-shared --enable-static --enable-libx264 --enable-gpl 
```

Some headers, such as ``config.h`` need to be copied to project after the ``configure``.

