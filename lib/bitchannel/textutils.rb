#
# $Id$
#
# Copyright (C) 2003 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.
#

module AlphaWiki

  module TextUtils

    private

    def wikiname?(name)
      /\A(?:[A-Z][a-z0-9]+){2,}\z/ =~ name
    end

    def beautify_wikiname(name)
      name.gsub(/(.)([A-Z])/) { "#{$1} #{$2}" }
    end

    ESC = {
      '&' => '&amp;',
      '"' => '&quot;',
      '<' => '&lt;',
      '>' => '&gt;'
    }

    def escape_html(str)
      table = ESC
      str.gsub(/[&"<>]/) {|s| table[s] }
    end

    ESCrev = ESC.invert

    def unescape_html(str)
      table = ESCrev
      str.gsub(/&\w+;/) {|s| table[s] }
    end

    def encode_filename(name)
      name.gsub(/[^a-z\d]/in) {|c| sprintf('%%%02x', c[0]) }
    end

    def decode_filename(name)
      name.gsub(/%([\da-h]{2})/i) { $1.hex.chr }
    end

    def format_time(time)
      # from tmail/textutils.rb
      gmt = Time.at(time.to_i)
      gmt.gmtime
      offset = time.to_i - Time.local(*gmt.to_a[0,6].reverse).to_i
      sprintf('%04d-%02d-%02d %02d:%02d:%02d %+.2d%.2d',
              time.year, time.month, time.mday,
              time.hour, time.min, time.sec,
              *(offset / 60).divmod(60))
    end

  end

end   # module AlphaWiki
