video2gif
=========

`video2gif` eases converting any video into a GIF.

It uses [FFMpeg], so it understands any video that [FFMpeg] does. It has
an array of options to allow you to select the part of the video you
want, crop it automatically, overlay text, and manipulate the color and
brightness.


Installation
------------

`video2gif` requires a recent version of [FFMpeg] installed and
available in the system `$PATH`. If you can run `ffmpeg` from the
command line, you're probably good. If not, use your favorite package
manager to install it.

Note that some features may not be available by default. For example,
tonemapping (used for HDR videos) requires `libzimg` support, not
included by default in the [FFMpeg] supplied by [Homebrew].

`video2gif` also requires Ruby and the ability to install a new gem. If
you have this available, run the following command to install it.

    gem install video2gif


Usage
-----

The general syntax for the command follows.

    video2gif <input video> [<output filename>] [<options>]

Use `video2gif --help` to see all the options available. Given an input
video, `video2gif` has a reasonable set of defaults to output a GIF of
the same size and with the same name in the same directory. However,
using the options available, you can change the output filename and the
appearance of the resulting GIF.

_Further documentation to come._


License
-------

This gem is released into the public domain (CC0 license). For details,
see: https://creativecommons.org/publicdomain/zero/1.0/legalcode


Contributing
------------

To contribute to this plugin, find it on GitHub. Please see the
[CONTRIBUTING](CONTRIBUTING.markdown) file accompanying it for
guidelines.

https://github.com/emilyst/video2gif
