# frozen_string_literal: true

require 'optparse'
require 'open3'
require 'logger'

require 'video2gif/version'


module Video2gif
  def self.is_executable?(command)
    ENV['PATH'].split(File::PATH_SEPARATOR).map do |path|
      (ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']).map do |extension|
        File.executable?(File.join(path, "#{command}#{extension}"))
      end
    end.flatten.any?
  end

  def self.parse_args(args, logger)
    options = {}

    parser = OptionParser.new do |parser|
      parser.banner = 'Usage: video2gif <video> [options] [<output GIF filename>]'
      parser.separator ''
      parser.separator 'General GIF options:'

      parser.on('-s SEEK',
                '--seek SEEK',
                'Set time to seek to in the input video (use a count of',
                'seconds or HH:MM:SS.SS format)') do |s|
        options[:seek] = s
      end

      parser.on('-t TIME',
                '--time TIME',
                'Set duration to use from the input video (use a count of',
                'seconds)') do |t|
        options[:time] = t
      end

      parser.on('-f FRAMES',
                '--fps FRAMES',
                'Set frames per second for the resulting GIF') do |f|
        options[:fps] = f
      end

      parser.on('-w WIDTH',
                '--width WIDTH',
                'Scale the width of the resulting GIF in pixels (aspect',
                'ratio is preserved)') do |w|
        options[:width] = w
      end

      # parser.on('-hHEIGHT', '--height=HEIGHT', 'Scale the height of the resulting GIF') do |h|
      #   options[:height] = h
      # end

      parser.on('-p PALETTE',
                '--palette PALETTE',
                'Set the palette size of the resulting GIF (maximum of 255',
                'colors)') do |p|
        options[:palette] = p
      end

      parser.on('-c SIZE',
                '--crop-size-w SIZE',
                'Pixel size of width to select from source video, before scaling') do |s|
        options[:wregion] = s
      end

      parser.on('-h SIZE',
                '--crop-size-h SIZE',
                'Pixel size of height to select from source video, before scaling') do |s|
        options[:hregion] = s
      end

      parser.on('-x OFFSET',
                '--crop-offset-x OFFSET',
                'Pixel offset from left to select from source video, before scaling') do |o|
        options[:xoffset] = o
      end

      parser.on('-y OFFSET',
                '--crop-offset-y OFFSET',
                'Pixel offset from top to select from source video, before scaling') do |o|
        options[:yoffset] = o
      end

      parser.on('-d [THRESHOLD]',
                '--crop-detect [THRESHOLD]',
                'Attempt automatic cropping based on black region, scaled',
                'from 0 (nothing) to 255 (everything), default threshold 24') do |c|
        options[:cropdetect] = c || 24
      end

      parser.on('--contrast CONTRAST',
                'Apply contrast adjustment, scaled from -2.0 to 2.0 (default 1)') do |c|
        options[:contrast] = c
        options[:eq] = true
      end

      parser.on('--brightness BRIGHTNESS',
                'Apply brightness adjustment, scaled from -1.0 to 1.0 (default 0)') do |b|
        options[:brightness] = b
        options[:eq] = true
      end

      parser.on('--saturation SATURATION',
                'Apply saturation adjustment, scaled from 0.0 to 3.0 (default 1)') do |s|
        options[:saturation] = s
        options[:eq] = true
      end

      parser.on('--gamma GAMMA',
                'Apply gamma adjustment, scaled from 0.1 to 10.0 (default 1)') do |g|
        options[:gamma] = g
        options[:eq] = true
      end

      parser.on('--red-gamma GAMMA',
                'Apply red channel gamma adjustment, scaled from 0.1 to 10.0 (default 1)') do |g|
        options[:gamma_r] = g
        options[:eq] = true
      end

      parser.on('--green-gamma GAMMA',
                'Apply green channel gamma adjustment, scaled from 0.1 to 10.0 (default 1)') do |g|
        options[:gamma_g] = g
        options[:eq] = true
      end

      parser.on('--blue-gamma GAMMA',
                'Apply blue channel gamma adjustment, scaled from 0.1 to 10.0 (default 1)') do |g|
        options[:gamma_b] = g
        options[:eq] = true
      end

      parser.on('--tonemap [ALGORITHM]',
                'Attempt to force tonemapping from HDR (BT.2020) to SDR',
                '(BT.709) using algorithm (experimental, requires ffmpeg with',
                'libzimg) (default "hable", "mobius" is a good alternative)') do |t|
        options[:tonemap] = t || 'hable'
      end

      parser.separator ''
      parser.separator 'Text overlay options (only used if text is defined):'

      parser.on('-T TEXT',
                '--text TEXT',
                'Set text to overlay on the GIF (use "\n" for line breaks)') do |p|
        options[:text] = p
      end

      parser.on('-C TEXTCOLOR',
                '--text-color TEXTCOLOR',
                'Set the color for text overlay') do |p|
        options[:textcolor] = p
      end

      parser.on('-S TEXTSIZE',
                '--text-size TEXTSIZE',
                'Set the point size for text overlay') do |p|
        options[:textsize] = p
      end

      parser.on('-B TEXTBORDER',
                '--text-border TEXTBORDER',
                'Set the width of the border for text overlay') do |p|
        options[:textborder] = p
      end

      parser.on('-F TEXTFONT',
                '--text-font TEXTFONT',
                'Set the font name for text overlay') do |p|
        options[:textfont] = p
      end

      parser.on('-V TEXTSTYLE',
                '--text-variant TEXTVARIANT',
                'Set the font variant for text overlay (e.g., "Semibold")') do |p|
        options[:textvariant] = p
      end

      parser.on('-X TEXTXPOS',
                '--text-x-position TEXTXPOS',
                'Set the X position for the text, starting from left (default is center)') do |p|
        options[:xpos] = p
      end

      parser.on('-Y TEXTXPOS',
                '--text-y-position TEXTYPOS',
                'Set the Y position for the text, starting from top (default is near bottom)') do |p|
        options[:ypos] = p
      end

      parser.separator ''
      parser.separator 'Other options:'

      parser.on_tail('-v', '--verbose', 'Show ffmpeg command executed and output') do |p|
        options[:verbose] = p
      end

      parser.on_tail('-q', '--quiet', 'Suppress all log output (overrides verbose)') do |p|
        options[:quiet] = p
      end

      parser.on_tail('-h', '--help', 'Show this message') do
        puts parser
        exit
      end

      parser.parse!(args)
    end

    parser.parse!

    unless is_executable?('ffmpeg')
      puts 'ERROR: Requires FFmpeg to be installed!'
      exit 1
    end

    if args.size < 1 || args.size > 2
      puts 'ERROR: Specify one video to convert at a time!'
      puts ''
      puts parser.help
      exit 1
    end

    unless File.exists?(args[0])
      puts "ERROR: Specified video file does not exist: #{args[0]}!"
      puts ''
      puts parser.help
      exit
    end

    options
  end

  def self.build_filter_complex(options)
    fps        = options[:fps]     || 15
    max_colors = options[:palette] ? "max_colors=#{options[:palette]}:" : ''
    width      = options[:width]   # default is not to scale at all

    # create filter elements
    fps_filter        = "fps=#{fps}"
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
                            contrast=#{options[:contrast] || 1}
                            brightness=#{options[:brightness] || 0}
                            saturation=#{options[:saturation] || 1}
                            gamma=#{options[:gamma] || 1}
                            gamma_r=#{options[:gamma_r] || 1}
                            gamma_g=#{options[:gamma_g] || 1}
                            gamma_b=#{options[:gamma_b] || 1}
                          ].join(':')
                        end
    palettegen_filter = "palettegen=max_colors=#{palette_size}:stats_mode=diff"
    paletteuse_filter = 'paletteuse=dither=sierra2_4a:diff_mode=rectangle'
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
    filter_complex << fps_filter
    filter_complex << crop_filter if crop_filter
    filter_complex << scale_filter if options[:width] unless options[:tonemap]
    filter_complex << tonemap_filters if options[:tonemap]
    filter_complex << eq_filter if options[:eq]
    filter_complex << drawtext_filter if options[:text]

    # then generate the palette (and label this filter stream)
    filter_complex << palettegen_filter + '[palette]'

    # then refer back to the first video input stream and the filter
    # complex stream to apply the generated palette to the video stream
    # along with the other filters (drawing text last so that it isn't
    # affected by scaling)
    filter_complex << '[0:v][palette]' + paletteuse_filter
    filter_complex << fps_filter
    filter_complex << crop_filter if crop_filter
    filter_complex << scale_filter if options[:width] unless options[:tonemap]
    filter_complex << tonemap_filters if options[:tonemap]
    filter_complex << eq_filter if options[:eq]
    filter_complex << drawtext_filter if options[:text]

    filter_complex.join(',')
  end

  def self.build_output_filename(args)
    if args[1]
      args[1].end_with?('.gif') ? args[1] : args[1] + '.gif'
    else
      File.join(File.dirname(args[0]),
                File.basename(args[0], '.*') + '.gif')
    end
  end

  def self.build_ffmpeg_gif_command(args, options, logger)
    command = []
    command << 'ffmpeg'
    command << '-y'  # always overwrite
    command << '-analyzeduration' << '2147483647' << '-probesize' << '2147483647'
    command << '-nostdin'
    command << '-ss' << options[:seek] if options[:seek]
    command << '-t' << options[:time] if options[:time]
    command << '-i' << args[0]
    command << '-filter_complex' << build_filter_complex(options)
    command << '-f' << 'gif'


    logger.info(command.join(' ')) if options[:verbose] unless options[:quiet]

    command
  end


  def self.build_ffmpeg_cropdetect_command(args, options, logger)
    command = []
    command << 'ffmpeg'
    command << '-analyzeduration' << '2147483647' << '-probesize' << '2147483647'
    command << '-nostdin'
    command << '-ss' << options[:seek] if options[:seek]
    command << '-t' << options[:time] if options[:time]
    command << '-i' << args[0]
    command << '-filter_complex' << "cropdetect=limit=#{options[:cropdetect]}"
    command << '-f' << 'null'
    command << '-'

    logger.info(command.join(' ')) if options[:verbose] unless options[:quiet]

    command
  end

  def self.run
    logger = Logger.new(STDOUT)
    options = parse_args(ARGV, logger)

    if options[:cropdetect]
      Open3.popen3(*build_ffmpeg_cropdetect_command(ARGV, options, logger)) do |stdin, stdout, stderr, wait_thr|
        stdin.close
        stdout.close
        stderr.each(chomp: true) do |line|
          logger.info(line) if options[:verbose] unless options[:quiet]
          options[:cropdetect] = line.match('crop=([0-9]+\:[0-9]+\:[0-9]+\:[0-9]+)') if line.include?('Parsed_cropdetect')
        end
        stderr.close

        raise "Process #{wait_thr.pid} failed! Try again with --verbose to see error." unless wait_thr.value.success?
      end
    end

    gif_pipeline_items = [build_ffmpeg_gif_command(ARGV, options, logger)]

    read_io, write_io = IO.pipe
    Open3.pipeline_start(*gif_pipeline_items, out: write_io, err: write_io) do |threads|
      write_io.close
      if options[:verbose]
        read_io.each(chomp: true) { |line| logger.info(line) unless options[:quiet] }
      else
        read_io.read(1024) until read_io.eof?
      end
      read_io.close

      threads.each do |t|
        raise "Process #{t.pid} failed! Try again with --verbose to see error." unless t.value.success?
      end
    end
  end
end
