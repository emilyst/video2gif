# frozen_string_literal: true

require 'optparse'
require 'video2gif'


module Video2gif
  module Options
    def self.parse(args)
      options = {}

      parser = OptionParser.new do |parser|
        parser.banner = <<~BANNER
          video2gif #{Video2gif::VERSION}

          Usage: video2gif <video> [<output GIF filename>] [options]
        BANNER

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
                  'Set frames per second for the resulting GIF (default 10)') do |f|
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

        parser.on('-d [ALGORITHM]',
                  '--[no-]dither [ALGORITHM]',
                  'Set the dithering algorithm for the palette generation",
                  "(default enabled with "floyd_steinberg")') do |d|
          if d.nil?
            options[:dither] = 'floyd_steinberg'
          else
            options[:dither] = d || 'none'
          end
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

        parser.on('-a [THRESHOLD]',
                  '--autocrop [THRESHOLD]',
                  'Attempt automatic cropping based on black region, scaled',
                  'from 0 (nothing) to 255 (everything), default threshold 24') do |c|
          options[:autocrop] = c || 24
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

        parser.on('--subtitles [INDEX]',
                  '(Experimental, requires ffprobe) Attempt to use the',
                  'subtitles built into the video to overlay text on the',
                  'resulting GIF. Takes an optional integer value to',
                  'choose the subtitle stream (defaults to the first',
                  'subtitle stream, index 0)') do |s|
          unless Video2gif::Utils.is_executable?('ffprobe')
            puts 'ERROR: Requires FFmpeg utils to be installed (for ffprobe)!'
            exit 1
          end

          options[:subtitles] = s || true
          options[:subtitle_index] =  if options[:subtitles].is_a?(TrueClass)  # default to first stream
                                        0
                                      elsif options[:subtitles].match?(/\A\d+\z/)  # select stream by index
                                        options[:subtitles].to_i
                                      elsif options[:subtitles].is_a?(String)  # open subtitles file
                                        puts 'ERROR: Selecting subtitles by filename is not yet supported!'
                                        exit 1
                                      end
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

      unless Video2gif::Utils.is_executable?('ffmpeg')
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

      options[:input_filename] = args[0]
      options[:output_filename] = if args[1]
                                    args[1].end_with?('.gif') ? args[1] : args[1] + '.gif'
                                  else
                                    File.join(File.dirname(args[0]),
                                              File.basename(args[0], '.*') + '.gif')
                                  end

      options
    end
  end
end
