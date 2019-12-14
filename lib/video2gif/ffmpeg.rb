# frozen_string_literal: true

require_relative 'ffmpeg/subtitles'


module Video2gif
  module FFmpeg
    include Subtitles

    CROP_REGEX = /crop=([0-9]+\:[0-9]+\:[0-9]+\:[0-9]+)/

    def self.video_info(options)
      options[:probe_infos][:streams].find { |s| s[:codec_type] == 'video' }
    end

    def self.rate(options)
      "setpts=PTS/#{options[:rate]}" if options[:rate]
    end

    def self.interpolate(options)
      if options[:rate] && Float(options[:rate]) < 1  # only interpolate slowed down video
        minterpolate_parameters = []

        minterpolate_parameters << 'mi_mode=mci'
        minterpolate_parameters << 'mc_mode=aobmc'
        minterpolate_parameters << 'me_mode=bidir'
        minterpolate_parameters << 'me=epzs'
        minterpolate_parameters << 'vsbmc=1'
        minterpolate_parameters << "fps=#{video_info(options)[:avg_frame_rate] }/#{options[:rate]}"

        'minterpolate=' + minterpolate_parameters.join(':')
      end
    end

    def self.rate_with_interpolation(options)
      [
        rate(options),
        interpolate(options)
      ]
    end

    def self.fps(options)
      "fps=#{ options[:fps] || 20 }"
    end

    def self.crop(options)
      crop_parameters = []

      crop_parameters << "w=#{options[:wregion]}" if options[:wregion]
      crop_parameters << "h=#{options[:hregion]}" if options[:hregion]
      crop_parameters << "x=#{options[:xoffset]}" if options[:xoffset]
      crop_parameters << "y=#{options[:yoffset]}" if options[:yoffset]

      'crop=' + crop_parameters.join(':') unless crop_parameters.empty?
    end

    def self.zscale(options)
      zscale_parameters = []

      zscale_parameters << 'dither=none'
      zscale_parameters << 'filter=lanczos'
      zscale_parameters << "width=#{ options[:width] || 480 }"
      zscale_parameters << "height=trunc(#{ options[:width] || 480 }/dar)"

      'zscale=' + zscale_parameters.join(':')
    end

    def self.tonemap(options)
      %W[
        zscale=transfer=linear
        tonemap=tonemap=#{options[:tonemap]}
        zscale=transfer=bt709
        format=gbrp
      ]
    end

    def self.zscale_and_tonemap(options)
      if options[:tonemap]
        [
          zscale(options),
          tonemap(options)
        ]
      end
    end

    def self.scale(options)
      unless options[:tonemap]
        scale_parameters = []

        scale_parameters << 'flags=lanczos'
        scale_parameters << 'sws_dither=none'
        scale_parameters << "width=#{ options[:width] || 480 }"
        scale_parameters << "height=trunc(#{ options[:width] || 480 }/dar)"

        'scale=' + scale_parameters.join(':')
      end
    end

    def self.eq(options)
      eq_parameters = []

      eq_parameters << "contrast=#{options[:contrast]}"     if options[:contrast]
      eq_parameters << "brightness=#{options[:brightness]}" if options[:brightness]
      eq_parameters << "saturation=#{options[:saturation]}" if options[:saturation]
      eq_parameters << "gamma=#{options[:gamma]}"           if options[:gamma]
      eq_parameters << "gamma_r=#{options[:gamma_r]}"       if options[:gamma_r]
      eq_parameters << "gamma_g=#{options[:gamma_g]}"       if options[:gamma_g]
      eq_parameters << "gamma_b=#{options[:gamma_b]}"       if options[:gamma_b]

      'eq=' + eq_parameters.join(":")
    end

    def self.text(options)
      options[:text].gsub(/\\n/,                                                        '')
                    .gsub(/([:])/,                                                      '\\\\\\\\\\1')
                    .gsub(/([,])/,                                                      '\\\\\\1')
                    .gsub(/\b'\b/,                                                      "\u2019")
                    .gsub(/\B"\b([^"\u201C\u201D\u201E\u201F\u2033\u2036\r\n]+)\b?"\B/, "\u201C\\1\u201D")
                    .gsub(/\B'\b([^'\u2018\u2019\u201A\u201B\u2032\u2035\r\n]+)\b?'\B/, "\u2018\\1\u2019")
    end

    def self.drawtext(options)
      if options[:text]
        count_of_lines = options[:text].scan(/\\n/).count + 1

        drawtext_parameters = []
        drawtext_parameters << "x='#{ options[:xpos] || '(main_w/2-text_w/2)' }'"
        drawtext_parameters << "y='#{ options[:ypos] || "(main_h-line_h*1.5*#{count_of_lines})" }'"
        drawtext_parameters << "fontsize='#{ options[:textsize] || 32 }'"
        drawtext_parameters << "fontcolor='#{ options[:textcolor] || 'white' }'"
        drawtext_parameters << "borderw='#{ options[:textborder] || 2 }'"
        drawtext_parameters << "fontfile='#{ options[:textfont] || 'Arial'}'\\\\:style='#{options[:textvariant] || 'Bold' }'"
        drawtext_parameters << "text='#{text(options)}'"

        'drawtext=' + drawtext_parameters.join(':')
      end
    end

    def self.split
      'split[palettegen][paletteuse]'
    end

    def self.palettegen(options)
      palettegen_parameters = []

      palettegen_parameters << "#{ options[:palette] || 256 }"
      palettegen_parameters << "stats_mode=#{options[:palettemode] || 'diff'}"

      '[palettegen]palettegen=' + palettegen_parameters.join(':') + '[palette]'
    end

    def self.paletteuse(options)
      paletteuse_parameters = []

      paletteuse_parameters << "dither=#{options[:dither] || 'floyd_steinberg'}"
      paletteuse_parameters << 'diff_mode=rectangle'
      paletteuse_parameters << "#{options[:palettemode] == 'single' ? 'new=1' : ''}"

      '[paletteuse][palette]paletteuse=' + paletteuse_parameters.join(':')
    end

    def self.filtergraph(options)
      filtergraph = []

      filtergraph << bitmap_subtitles_scale_overlay(options)
      filtergraph << rate_with_interpolation(options)
      filtergraph << fps(options)
      filtergraph << options[:autocrop] if options[:autocrop]
      filtergraph << crop(options)
      filtergraph << zscale_and_tonemap(options)
      filtergraph << scale(options)
      filtergraph << eq(options)
      filtergraph << text_subtitles(options)
      filtergraph << drawtext(options)
      filtergraph << split
      filtergraph << palettegen(options)
      filtergraph << paletteuse(options)

      filtergraph.flatten.compact
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
      command << '-an'
      command << '-sn'
      command << '-dn'
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
