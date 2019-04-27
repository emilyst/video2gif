# frozen_string_literal: true


module Video2gif
  module FFmpeg
    CROP_REGEX = /crop=([0-9]+\:[0-9]+\:[0-9]+\:[0-9]+)/

    def self.filtergraph(options)
      filtergraph = []

      if options[:subtitles] && options[:probe_infos][:streams].any? do |s|
        s[:codec_type] == 'subtitle'
      end
        video_info = options[:probe_infos][:streams].find { |s| s[:codec_type] == 'video' }
        subtitle_info = options[:probe_infos][:streams].find_all { |s| s[:codec_type] == 'subtitle' }[options[:subtitle_index]]

        if Video2gif::FFmpeg::Subtitles::KNOWN_TEXT_FORMATS.include?(subtitle_info[:codec_name])
          filtergraph << "setpts=PTS+#{Video2gif::Utils.duration_to_seconds(options[:seek])}/TB"
          filtergraph << "subtitles='#{options[:input_filename]}':si=#{options[:subtitle_index]}"
          filtergraph << 'setpts=PTS-STARTPTS'
        elsif Video2gif::FFmpeg::Subtitles::KNOWN_BITMAP_FORMATS.include?(subtitle_info[:codec_name])
          filtergraph << "[0:s:#{options[:subtitle_index]}]scale=" + %W[
            flags=lanczos
            sws_dither=none
            width=#{video_info[:width]}
            height=#{video_info[:height]}
          ].join(':') + '[subs]' if options[:width]
          filtergraph << "[0:v][subs]overlay=format=auto"
        end
      end

      # Set 'fps' filter first, drop unneeded frames instead of
      # processing those.
      filtergraph << "fps=#{ options[:fps] || 10 }"

      # Crop if needed, using either settings discovered during the
      # autocrop run or manually set parameters, so we don't process
      # additional parts of the image (and exclude it from palette
      # generation).
      if options[:autocrop]
        filtergraph << options[:autocrop]
      elsif options[:wregion] ||
            options[:hregion] ||
            options[:xoffset] ||
            options[:yoffset]
        filtergraph << 'crop=' + [
          "w=#{ options[:wregion] || 'in_w' }",
          "h=#{ options[:hregion] || 'in_h' }",
          "x=#{ options[:xoffset] || 0 }",
          "y=#{ options[:yoffset] || 0 }",
        ].join(':')
      end

      # Scale here before other filters to avoid unnecessary processing.
      if options[:tonemap]
        # If we're attempting to convert HDR to SDR, use a set of
        # 'zscale' filters, 'format' filters, and the 'tonemap' filter.
        # The 'zscale' will do the resize for us as well.
        filtergraph << 'zscale=' + %W[
           dither=none
           filter=lanczos
           width=#{options[:width]}
           height=trunc(#{options[:width]}/dar)
        ].join(':') if options[:width]
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
          width=#{options[:width]}
          height=trunc(#{options[:width]}/dar)
        ].join(':') if options[:width] && !options[:tonemap]
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
          borderw='#{ options[:textborder] || 3 }'
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
      filtergraph << "[palettegen]palettegen=#{options[:palette] || 256}:stats_mode=diff[palette]"

      # Using a copy of the stream from the 'split' filter and the
      # generated palette as inputs, apply the final palette to the GIF.
      # For non-moving parts of the GIF, attempt to reuse the same
      # palette from frame to frame.
      filtergraph << "[paletteuse][palette]paletteuse=dither=#{options[:dither] || 'floyd_steinberg'}:diff_mode=rectangle"
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
      command << '-analyzeduration' << '2147483647' << '-probesize' << '2147483647'
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
