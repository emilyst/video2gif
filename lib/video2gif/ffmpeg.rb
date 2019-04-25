# frozen_string_literal: true


module Video2gif
  module FFMpeg
    def self.filter_complex(options)
      filter_complex = []

      filter_complex << "fps=#{ options[:fps] || 10 }"

      if options[:autocrop]
        filter_complex << options[:autocrop]
      else
        filter_complex << 'crop=' + [
          "w=#{ options[:wregion] || 'in_w' }",
          "h=#{ options[:hregion] || 'in_h' }",
          "x=#{ options[:xoffset] || 0 }",
          "y=#{ options[:yoffset] || 0 }",
        ].join(':')
      end

      if options[:width] && !options[:tonemap]
        filter_complex << "scale=flags=lanczos:sws_dither=none:width=#{options[:width]}:height=-1"
      end

      if options[:tonemap]
        filter_complex << "zscale=dither=none:filter=lanczos:width=#{options[:width]}:height=-1" if options[:width]
        filter_complex << 'zscale=transfer=linear:npl=100'
        filter_complex << 'zscale=npl=100'
        filter_complex << 'format=gbrpf32le'
        filter_complex << 'zscale=primaries=bt709'
        filter_complex << "tonemap=tonemap=#{options[:tonemap]}:desat=0"
        filter_complex << 'zscale=transfer=bt709:matrix=bt709:range=tv'
        filter_complex << 'format=yuv420p'
      end

      filter_complex << "eq=contrast=#{options[:contrast]}"     if options[:contrast]
      filter_complex << "eq=brightness=#{options[:brightness]}" if options[:brightness]
      filter_complex << "eq=saturation=#{options[:saturation]}" if options[:saturation]
      filter_complex << "eq=gamma=#{options[:gamma]}"           if options[:gamma]
      filter_complex << "eq=gamma_r=#{options[:gamma_r]}"       if options[:gamma_r]
      filter_complex << "eq=gamma_g=#{options[:gamma_g]}"       if options[:gamma_g]
      filter_complex << "eq=gamma_b=#{options[:gamma_b]}"       if options[:gamma_b]

      if options[:text]
        count_of_lines = options[:text].scan(/\\n/).count + 1
        text = options[:text]
          .gsub(/\\n/,                                                        '')
          .gsub(/([:])/,                                                      '\\\\\\\\\\1')
          .gsub(/([,])/,                                                      '\\\\\\1')
          .gsub(/\b'\b/,                                                      "\u2019")
          .gsub(/\B"\b([^"\u201C\u201D\u201E\u201F\u2033\u2036\r\n]+)\b?"\B/, "\u201C\\1\u201D")
          .gsub(/\B'\b([^'\u2018\u2019\u201A\u201B\u2032\u2035\r\n]+)\b?'\B/, "\u2018\\1\u2019")

        filter_complex << 'drawtext=' + [
          "x='#{ options[:xpos] || '(main_w/2-text_w/2)' }'",
          "y='#{ options[:ypos] || "(main_h-line_h*1.5*#{count_of_lines})" }'",
          "fontsize='#{ options[:textsize] || 32 }'",
          "fontcolor='#{ options[:textcolor] || 'white' }'",
          "borderw='#{ options[:textborder] || 3 }'",
          "fontfile='#{ options[:textfont] || 'Arial'}'\\\\:style='#{options[:textvariant] || 'Bold' }'",
          "text='#{text}'",
        ].join(':')
      end

      filter_complex << 'split [o1] [o2]'
      if options[:palette]
        filter_complex << "[o1] palettegen=#{options[:palette]}:stats_mode=diff [p]"
      else
        filter_complex << "[o1] palettegen=stats_mode=diff [p]"
      end
      filter_complex << '[o2] fifo [o3]'
      filter_complex << '[o3] [p] paletteuse=dither=floyd_steinberg:diff_mode=rectangle'

      filter_complex.join(',')
    end

    def self.cropdetect_command(options, logger)
      command = ['ffmpeg']
      command << '-analyzeduration' << '2147483647' << '-probesize' << '2147483647'
      command << '-ss' << options[:seek] if options[:seek]
      command << '-t' << options[:time] if options[:time]
      command << '-i' << options[:input_filename]
      command << '-filter_complex' << "cropdetect=limit=#{options[:autocrop]}"
      command << '-f' << 'null'
      command << '-'

      logger.info(command.join(' ')) if options[:verbose] unless options[:quiet]

      command
    end

    def self.gif_command(options, logger)
      command = ['ffmpeg']
      command << '-y'  # always overwrite
      command << '-analyzeduration' << '2147483647' << '-probesize' << '2147483647'
      command << '-loglevel' << 'level+verbose'
      command << '-ss' << options[:seek] if options[:seek]
      command << '-t' << options[:time] if options[:time]
      command << '-i' << options[:input_filename]
      command << '-filter_complex' << filter_complex(options)
      command << '-f' << 'gif'
      command << options[:output_filename]

      logger.info(command.join(' ')) if options[:verbose] unless options[:quiet]

      command
    end
  end
end
