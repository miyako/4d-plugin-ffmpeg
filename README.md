# 4d-plugin-ffmpeg
boilerplate project for static ffmpeg plugin edition

* ffmpeg Mac: ``4.2.1`` Windows: ``3.3`` TODO: update vcpkg to ``4.1`` 

**work in progress** 

#### Why build a plugin?

``ffmpeg`` and ``mp4box`` are essential tools for creating video contents for streaming.

c.f. [Making Your Own Simple MPEG-DASH Server](https://www.instructables.com/id/Making-Your-Own-Simple-DASH-MPEG-Server-Windows-10/)

With 4D, static builds of [``ffmpeg``](https://ffmpeg.zeranoe.com/builds/) and [``mp4box``](https://gpac.wp.imt.fr/2015/07/29/gpac-build-mp4box-only-all-platforms/) can be distributed with the application, invoked via ``LAUNCH EXTERNAL PROCESS``. That option is explored [here](https://github.com/miyako/4d-video-server-example).
