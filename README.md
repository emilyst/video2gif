video2gif
=========

`video2gif` eases converting any video into a GIF.

It uses [FFmpeg], so it understands any video that [FFmpeg] does. It has
an array of options to allow you to select the part of the video you
want, crop it automatically, overlay text, and manipulate the color and
brightness.


Status
------

Currently, `video2gif` is in alpha status: it is feature-incomplete, not
guaranteed to work at all, and subject to change features, options, or
defaults. The [patch-level version] will increment for each change until
it is ready for beta status.

Planned before beta status is

* full documentation, including a manual page;
* full tests, including integration tests using `ffmpeg`;
* feature and configuration stability;
* better output, such as error output;
* friendlier command-line configuration;
* the ability to configure text-based subtitles; and
* the ability to incorporate subtitles from an external file.


Installation
------------

`video2gif` is a command-line tool requiring both Ruby and a recent
version of [FFmpeg] installed and available in the system `$PATH`. If
you can run `ffmpeg` and `ffprobe` from the command line, you likely
have the ability to run `video2gif`.

Note that some features may not work by default. For example,
tonemapping (used for HDR videos) requires `libzimg` support, not
included by default in the [FFmpeg] supplied by [Homebrew]. If you
attempt to use it, you will get an error.

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


[FFmpeg]: https://ffmpeg.org
[patch-level version]: https://semver.org
[Homebrew]: https://brew.sh
