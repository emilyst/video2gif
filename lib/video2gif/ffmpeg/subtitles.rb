# frozen_string_literal: true


module Video2gif
  module FFmpeg
    module Subtitles
      KNOWN_TEXT_FORMATS = %w[
        ass
        dvb_teletext
        eia_608
        hdmv_text_subtitle
        jacosub
        microdvd
        mov_text
        mpl2
        pjs
        realtext
        sami
        srt
        ssa
        stl
        subrip
        subviewer
        subviewer1
        text
        ttml
        vplayer
        webvtt
      ].freeze

      KNOWN_BITMAP_FORMATS = %w[
        dvb_subtitle
        dvd_subtitle
        hdmv_pgs_subtitle
        xsub
      ].freeze

      def self.included(m)
        m.extend(ClassMethods)
      end

      module ClassMethods
        def has_subtitles(options)
          options[:subtitles] && options[:probe_infos][:streams].any? { |s| s[:codec_type] == 'subtitle' }
        end

        def subtitle_info(options)
          if has_subtitles(options)
            options[:probe_infos][:streams].find_all { |s| s[:codec_type] == 'subtitle' }
                                           .fetch(options[:subtitle_index], nil)
          end
        end

        def has_bitmap_subtitles(options)
          has_subtitles(options) && KNOWN_BITMAP_FORMATS.include?(subtitle_info(options)[:codec_name])
        end

        def has_text_subtitles(options)
          has_subtitles(options) && KNOWN_TEXT_FORMATS.include?(subtitle_info(options)[:codec_name])
        end

        def subtitles_scale(options)
          scale_parameters = []

          scale_parameters << 'flags=lanczos'
          scale_parameters << 'sws_dither=none'
          scale_parameters << "width=#{video_info(options)[:width]}"
          scale_parameters << "height=#{video_info(options)[:height]}"

          "[0:s:#{options[:subtitle_index]}]scale=#{scale_parameters.join(':')}[subs]"
        end

        def subtitles_overlay
          '[0:v][subs]overlay=format=auto'
        end

        def bitmap_subtitles_scale_overlay(options)
          if has_bitmap_subtitles(options)
            [
              subtitles_scale(options),
              subtitles_overlay
            ]
          end
        end

        def text_subtitles(options)
          if has_text_subtitles(options)
            %W[
              setpts=PTS+#{Utils.duration_to_seconds(options[:seek])}/TB
              subtitles='#{options[:input_filename]}':si=#{options[:subtitle_index]}
              setpts=PTS-STARTPTS
            ]
          end
        end
      end
    end
  end
end
