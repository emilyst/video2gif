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
      ]

      KNOWN_BITMAP_FORMATS = %w[
        dvb_subtitle
        dvd_subtitle
        hdmv_pgs_subtitle
        xsub
      ]
    end
  end
end

