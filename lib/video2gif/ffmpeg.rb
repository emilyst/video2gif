# frozen_string_literal: true


module Video2gif
  module FFMpeg
    def self.filter_complex(options)
      fps        = options[:fps]     || 10
      max_colors = options[:palette] ? "max_colors=#{options[:palette]}:" : ''
      width      = options[:width]   # default is not to scale at all

      # create filter elements
      palettegen_fps_filter = "fps=2"  # sample only a few frames a second
      paletteuse_fps_filter = "fps=#{fps}"
      crop_filter       = options[:cropdetect] || 'crop=' + %W[
                                                     w=#{ options[:wregion] || 'in_w' }
                                                     h=#{ options[:hregion] || 'in_h' }
                                                     x=#{ options[:xoffset] || 0 }
                                                     y=#{ options[:yoffset] || 0 }
                                                  ].join(':')
      scale_filter      = "scale=#{width}:-1:flags=lanczos:sws_dither=none" if options[:width] unless options[:tonemap]
      tonemap_filters   = if options[:tonemap]  # TODO: detect input format
                            %W[
                              zscale=w=#{width}:h=-1
                              zscale=t=linear:npl=100
                              format=yuv420p10le
                              zscale=p=bt709
                              tonemap=tonemap=#{options[:tonemap]}:desat=0
                              zscale=t=bt709:m=bt709:r=tv
                              format=yuv420p
                            ].join(',')
                          end
      eq_filter         = if options[:eq]
                            'eq=' + %W[
                              contrast=#{ options[:contrast] || 1 }
                              brightness=#{ options[:brightness] || 0 }
                              saturation=#{ options[:saturation] || 1 }
                              gamma=#{ options[:gamma] || 1 }
                              gamma_r=#{ options[:gamma_r] || 1 }
                              gamma_g=#{ options[:gamma_g] || 1 }
                              gamma_b=#{ options[:gamma_b] || 1 }
                            ].join(':')
                          end
      palettegen_filter = "palettegen=#{max_colors}stats_mode=diff"
      paletteuse_filter = 'paletteuse=dither=floyd_steinberg:diff_mode=rectangle'
      drawtext_filter   = if options[:text]
                            count_of_lines = options[:text].scan(/\\n/).count + 1

                            x      = options[:xpos]        || '(main_w/2-text_w/2)'
                            y      = options[:ypos]        || "(main_h-line_h*1.5*#{count_of_lines})"
                            size   = options[:textsize]    || 32
                            color  = options[:textcolor]   || 'white'
                            border = options[:textborder]  || 3
                            font   = options[:textfont]    || 'Arial'
                            style  = options[:textvariant] || 'Bold'
                            text   = options[:text]
                              .gsub(/\\n/,                                                        '')
                              .gsub(/([:])/,                                                      '\\\\\\\\\\1')
                              .gsub(/([,])/,                                                      '\\\\\\1')
                              .gsub(/\b'\b/,                                                      "\u2019")
                              .gsub(/\B"\b([^"\u201C\u201D\u201E\u201F\u2033\u2036\r\n]+)\b?"\B/, "\u201C\\1\u201D")
                              .gsub(/\B'\b([^'\u2018\u2019\u201A\u201B\u2032\u2035\r\n]+)\b?'\B/, "\u2018\\1\u2019")

                            'drawtext=' + %W[
                              x='#{x}'
                              y='#{y}'
                              fontsize='#{size}'
                              fontcolor='#{color}'
                              borderw='#{border}'
                              fontfile='#{font}'\\\\:style='#{style}'
                              text='#{text}'
                            ].join(':')
                          end

      filter_complex = []

      # first, apply the same filters we'll use later in the same order
      # before applying the palettegen so that we accurately predict the
      # final palette
      filter_complex << palettegen_fps_filter
      filter_complex << crop_filter     if crop_filter
      filter_complex << scale_filter    if options[:width] unless options[:tonemap]
      filter_complex << tonemap_filters if options[:tonemap]
      filter_complex << eq_filter       if options[:eq]
      filter_complex << drawtext_filter if options[:text]

      # then generate the palette (and label this filter stream)
      filter_complex << palettegen_filter + '[palette]'

      # then refer back to the first video input stream and the filter
      # complex stream to apply the generated palette to the video stream
      # along with the other filters (drawing text last so that it isn't
      # affected by scaling)
      filter_complex << '[0:v][palette]' + paletteuse_filter
      filter_complex << paletteuse_fps_filter
      filter_complex << crop_filter     if crop_filter
      filter_complex << scale_filter    if options[:width] unless options[:tonemap]
      filter_complex << tonemap_filters if options[:tonemap]
      filter_complex << eq_filter       if options[:eq]
      filter_complex << drawtext_filter if options[:text]

      filter_complex.join(',')
    end

    def self.cropdetect_command(options, logger)
      command = ['ffmpeg']
      command << '-analyzeduration' << '2147483647' << '-probesize' << '2147483647'
      command << '-nostdin'
      command << '-ss' << options[:seek] if options[:seek]
      command << '-t' << options[:time] if options[:time]
      command << '-i' << options[:input_filename]
      command << '-filter_complex' << "cropdetect=limit=#{options[:cropdetect]}"
      command << '-f' << 'null'
      command << '-'

      logger.info(command.join(' ')) if options[:verbose] unless options[:quiet]

      command
    end

    def self.gif_command(options, logger)
      command = ['ffmpeg']
      command << '-y'  # always overwrite
      command << '-analyzeduration' << '2147483647' << '-probesize' << '2147483647'
      command << '-nostdin'
      command << '-ss' << options[:seek] if options[:seek]
      command << '-t' << options[:time] if options[:time]
      command << '-i' << options[:input_filename]
      command << '-filter_complex' << filter_complex(options)
      command << '-gifflags' << '+transdiff'  # enabled by default
      command << '-f' << 'gif'
      command << options[:output_filename]

      logger.info(command.join(' ')) if options[:verbose] unless options[:quiet]

      command
    end
  end
end
