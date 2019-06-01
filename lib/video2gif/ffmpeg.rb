# frozen_string_literal: true


module Video2gif
  module FFmpeg
    CROP_REGEX = /crop=([0-9]+\:[0-9]+\:[0-9]+\:[0-9]+)/

    # TODO: This whole method needs to be broken up significantly.
    def self.filtergraph(options)
      filtergraph = []

      # If we want subtitles and *have* subtitles, we need some info to
      # use them.
      if options[:subtitles] && options[:probe_infos][:streams].any? { |s| s[:codec_type] == 'subtitle' }
        video_info = options[:probe_infos][:streams].find { |s| s[:codec_type] == 'video' }
        subtitle_info = options[:probe_infos][:streams].find_all { |s| s[:codec_type] == 'subtitle' }[options[:subtitle_index]]
      end

      # Bitmap formatted subtitles go first so that they get scaled
      # correctly.
      if options[:subtitles] &&
          options[:probe_infos][:streams].any? { |s| s[:codec_type] == 'subtitle' } &&
          Subtitles::KNOWN_BITMAP_FORMATS.include?(subtitle_info[:codec_name])
        filtergraph << "[0:s:#{options[:subtitle_index]}]scale=" + %W[
          flags=lanczos
          sws_dither=none
          width=#{video_info[:width]}
          height=#{video_info[:height]}
        ].join(':') + '[subs]'
        filtergraph << '[0:v][subs]overlay=format=auto'
      end

      # Set 'fps' filter first, drop unneeded frames instead of
      # processing those.
      filtergraph << "fps=#{ options[:fps] || 10 }"

      # Apply automatic cropping discovered during the cropdetect run.
      filtergraph << options[:autocrop] if options[:autocrop]

      # Apply manual cropping, if any.
      filtergraph << "crop=w=#{options[:wregion]}" if options[:wregion]
      filtergraph << "crop=h=#{options[:hregion]}" if options[:hregion]
      filtergraph << "crop=x=#{options[:xoffset]}" if options[:xoffset]
      filtergraph << "crop=y=#{options[:yoffset]}" if options[:yoffset]

      # Scale here before other filters to avoid unnecessary processing.
      if options[:tonemap]
        # If we're attempting to convert HDR to SDR, use a set of
        # 'zscale' filters, 'format' filters, and the 'tonemap' filter.
        # The 'zscale' will do the resize for us as well.
        filtergraph << 'zscale=' + %W[
          dither=none
          filter=lanczos
          width=#{ options[:width] || 400 }
          height=trunc(#{ options[:width] || 400 }/dar)
        ].join(':')
        filtergraph << 'zscale=transfer=linear:npl=100'
        filtergraph << 'zscale=npl=100'
        filtergraph << 'format=gbrpf32le'
        filtergraph << 'zscale=primaries=bt709'
        filtergraph << "tonemap=tonemap=#{options[:tonemap]}:desat=0"
        filtergraph << 'zscale=transfer=bt709:matrix=bt709:range=tv'
        filtergraph << 'format=yuv420p'
      else
        # If we're not attempting to convert HDR to SDR, the standard
        # 'scale' filter is preferred (if we're resizing at all).
        filtergraph << 'scale=' + %W[
          flags=lanczos
          sws_dither=none
          width=#{ options[:width] || 400 }
          height=trunc(#{ options[:width] || 400 }/dar)
        ].join(':') unless options[:tonemap]
      end

      # Perform any desired equalization before we overlay text so that
      # it won't be affected.
      filtergraph << "eq=contrast=#{options[:contrast]}"     if options[:contrast]
      filtergraph << "eq=brightness=#{options[:brightness]}" if options[:brightness]
      filtergraph << "eq=saturation=#{options[:saturation]}" if options[:saturation]
      filtergraph << "eq=gamma=#{options[:gamma]}"           if options[:gamma]
      filtergraph << "eq=gamma_r=#{options[:gamma_r]}"       if options[:gamma_r]
      filtergraph << "eq=gamma_g=#{options[:gamma_g]}"       if options[:gamma_g]
      filtergraph << "eq=gamma_b=#{options[:gamma_b]}"       if options[:gamma_b]

      # Embed text subtitles later so that they don't get processed by
      # cropping, etc., which might accidentally crop them out.
      if options[:subtitles] &&
          options[:probe_infos][:streams].any? { |s| s[:codec_type] == 'subtitle' } &&
          Subtitles::KNOWN_TEXT_FORMATS.include?(subtitle_info[:codec_name])
        filtergraph << "setpts=PTS+#{Utils.duration_to_seconds(options[:seek])}/TB"
        filtergraph << "subtitles='#{options[:input_filename]}':si=#{options[:subtitle_index]}"
        filtergraph << 'setpts=PTS-STARTPTS'
      end

      # If there is text to superimpose, do it here before palette
      # generation to ensure the color looks appropriate.
      if options[:text]
        count_of_lines = options[:text].scan(/\\n/).count + 1
        text = options[:text]
          .gsub(/\\n/,                                                        '')
          .gsub(/([:])/,                                                      '\\\\\\\\\\1')
          .gsub(/([,])/,                                                      '\\\\\\1')
          .gsub(/\b'\b/,                                                      "\u2019")
          .gsub(/\B"\b([^"\u201C\u201D\u201E\u201F\u2033\u2036\r\n]+)\b?"\B/, "\u201C\\1\u201D")
          .gsub(/\B'\b([^'\u2018\u2019\u201A\u201B\u2032\u2035\r\n]+)\b?'\B/, "\u2018\\1\u2019")

        filtergraph << 'drawtext=' + %W[
          x='#{ options[:xpos] || '(main_w/2-text_w/2)' }'
          y='#{ options[:ypos] || "(main_h-line_h*1.5*#{count_of_lines})" }'
          fontsize='#{ options[:textsize] || 32 }'
          fontcolor='#{ options[:textcolor] || 'white' }'
          borderw='#{ options[:textborder] || 1 }'
          fontfile='#{ options[:textfont] || 'Arial'}'\\\\:style='#{options[:textvariant] || 'Bold' }'
          text='#{text}'
        ].join(':')
      end

      # Split the stream into two copies, labeled with output pads for
      # the palettegen/paletteuse filters to use.
      filtergraph << 'split[palettegen][paletteuse]'

      # Using a copy of the stream created above labeled "palettegen",
      # generate a palette from the stream using the specified number of
      # colors and optimizing for moving objects in the stream. Label
      # this stream's output as "palette."
      filtergraph << '[palettegen]palettegen=' + %W[
        #{options[:palette] || 256}
        stats_mode=#{options[:palettemode] || 'diff'}
      ].join(':') + '[palette]'

      # Using a copy of the stream from the 'split' filter and the
      # generated palette as inputs, apply the final palette to the GIF.
      # For non-moving parts of the GIF, attempt to reuse the same
      # palette from frame to frame.
      filtergraph << '[paletteuse][palette]paletteuse=' + %W[
        dither=#{options[:dither] || 'floyd_steinberg'}
        diff_mode=rectangle
        #{options[:palettemode] == 'single' ? 'new=1' : ''}
      ].join(':')
    end

    def self.ffprobe_command(options, logger, executable: 'ffprobe')
      command = [executable]
      command << '-v' << 'error'
      command << '-show_entries' << 'stream'
      command << '-print_format' << 'json'
      command << '-i' << options[:input_filename]

      logger.info(command.join(' ')) if options[:verbose] unless options[:quiet]

      command
    end

    def self.ffmpeg_command(options, executable: 'ffmpeg')
      command = [executable]
      command << '-y'
      command << '-hide_banner'
      # command << '-analyzeduration' << '2147483647' << '-probesize' << '2147483647'
      command << '-loglevel' << 'verbose'
      command << '-ss' << options[:seek] if options[:seek]
      command << '-t' << options[:time] if options[:time]
      command << '-i' << options[:input_filename]
    end

    def self.cropdetect_command(options, logger, executable: 'ffmpeg')
      command = ffmpeg_command(options, executable: executable)
      command << '-filter_complex' << "cropdetect=limit=#{options[:autocrop]}"
      command << '-f' << 'null'
      command << '-'

      logger.info(command.join(' ')) if options[:verbose] unless options[:quiet]

      command
    end

    def self.gif_command(options, logger, executable: 'ffmpeg')
      command = ffmpeg_command(options, executable: executable)
      command << '-filter_complex' << filtergraph(options).join(',')
      command << '-f' << 'gif'
      command << options[:output_filename]

      logger.info(command.join(' ')) if options[:verbose] unless options[:quiet]

      command
    end
  end
end
