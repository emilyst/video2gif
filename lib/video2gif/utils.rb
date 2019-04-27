# frozen_string_literal: true


module Video2gif
  module Utils
    def self.is_executable?(command)
      ENV['PATH'].split(File::PATH_SEPARATOR).map do |path|
        (ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']).map do |extension|
          File.executable?(File.join(path, "#{command}#{extension}"))
        end
      end.flatten.any?
    end

    # Convert "[-][HH:]MM:SS[.m...]" to "[-]S+[.m...]".
    # https://ffmpeg.org/ffmpeg-utils.html#time-duration-syntax
    def self.duration_to_seconds(duration)
      return duration unless duration.include?(?:)
      m = duration.match(/(?<sign>-)?(?<hours>\d+:)?(?<minutes>\d+):(?<seconds>\d+)(?<millis>\.\d+)?/)
      seconds = m[:hours].to_i * 60 * 60 + m[:minutes].to_i * 60 + m[:seconds].to_i
      duration = "#{m[:sign]}#{seconds}#{m[:millis]}"
    end
  end
end
