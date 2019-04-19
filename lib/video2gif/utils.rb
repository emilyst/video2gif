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
  end
end
