# frozen_string_literal: true

require 'json'
require 'logger'
require 'open3'
require 'video2gif'


module Video2gif
  module CLI
    def self.start
      unless Utils.is_executable?('ffmpeg')
        puts 'ERROR: Requires FFmpeg to be installed!'
        exit 1
      end

      unless Utils.is_executable?('ffprobe')
        puts 'ERROR: Requires FFmpeg utils to be installed (for ffprobe)!'
        exit 1
      end

      logger = Logger.new(STDOUT)
      options = Options.parse(ARGV)

      lines = []

      Open3.popen2e(*FFmpeg.ffprobe_command(options, logger)) do |stdin, stdout_stderr, thread|
        stdin.close
        stdout_stderr.each do |line|
          logger.info(line.chomp) if options[:verbose] unless options[:quiet]
          lines << line
        end
        stdout_stderr.close

        unless thread.value.success?
          # TODO: more info, output lines with errors?
          raise "Process #{thread.pid} failed! Try again with --verbose to see error."
        end
      end

      options[:probe_infos] = JSON.parse(lines.join, symbolize_names: true)

      if options[:subtitles] && !options[:probe_infos][:streams].any? { |s| s[:codec_type] == 'subtitle' }
        logger.warn('Could not find subtitles in the file, they will be omitted') unless options[:quiet]
      end

      if options[:autocrop]
        Open3.popen2e(*FFmpeg.cropdetect_command(options, logger)) do |stdin, stdout_stderr, thread|
          stdin.close
          stdout_stderr.each do |line|
            logger.info(line.chomp) if options[:verbose] unless options[:quiet]
            if line.include?('Parsed_cropdetect')
              options[:autocrop] = line.match(FFmpeg::CROP_REGEX)
            end
          end
          stdout_stderr.close

          unless thread.value.success?
            # TODO: more info, output lines with errors?
            raise "Process #{thread.pid} failed! Try again with --verbose to see error."
          end
        end
      end

      Open3.popen2e(*FFmpeg.gif_command(options, logger)) do |stdin, stdout_stderr, thread|
        stdin.close
        stdout_stderr.each do |line|
          logger.info(line.chomp) if options[:verbose] unless options[:quiet]
        end
        stdout_stderr.close

        unless thread.value.success?
          # TODO: more info, output lines with errors?
          raise "Process #{thread.pid} failed! Try again with --verbose to see error."
        end
      end
    end
  end
end
