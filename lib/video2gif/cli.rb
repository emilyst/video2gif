# frozen_string_literal: true

require 'logger'
require 'open3'
require 'video2gif'


module Video2gif
  module CLI
    def self.start
      logger = Logger.new(STDOUT)
      options = Video2gif::Options.parse(ARGV)

      if options[:autocrop]
        Open3.popen2e(*Video2gif::FFMpeg.cropdetect_command(options, logger)) do |stdin, stdout_stderr, thread|
          stdin.close
          stdout_stderr.each do |line|
            logger.info(line.chomp) if options[:verbose] unless options[:quiet]
            if line.include?('Parsed_cropdetect')
              options[:autocrop] = line.match('crop=([0-9]+\:[0-9]+\:[0-9]+\:[0-9]+)')
            end
          end
          stdout_stderr.close

          unless thread.value.success?
            raise "Process #{thread.pid} failed! Try again with --verbose to see error."
          end
        end
      end

      Open3.popen2e(*Video2gif::FFMpeg.gif_command(options, logger)) do |stdin, stdout_stderr, thread|
        stdin.close
        stdout_stderr.each do |line|
          logger.info(line.chomp) if options[:verbose] unless options[:quiet]
        end
        stdout_stderr.close

        unless thread.value.success?
          raise "Process #{thread.pid} failed! Try again with --verbose to see error."
        end
      end
    end
  end
end
