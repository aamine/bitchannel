#
# $Id$
#
# Copyright (C) 2003,2004 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

module BitChannel

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
      table = ESC   # optimize
      str.gsub(/[&"<>]/) {|s| table[s] }
    end

    ESCrev = ESC.invert

    def unescape_html(str)
      table = ESCrev   # optimize
      str.gsub(/&\w+;/) {|s| table[s] }
    end

    def format_time(time)
      # strftime() is locale sensitive, we should not rely on strftime().
      # From tmail/textutils.rb:
      gmt = Time.at(time.to_i)
      gmt.gmtime
      offset = time.to_i - Time.local(*gmt.to_a[0,6].reverse).to_i
      sprintf('%04d-%02d-%02d %02d:%02d:%02d %+.2d%.2d',
              time.year, time.month, time.mday,
              time.hour, time.min, time.sec,
              *(offset / 60).divmod(60))
    end

    def times_before(time)
      diff = (Time.now - time).to_i
      case
      when diff < 60 * 60      then "#{diff / 60}m"
      when diff < 60 * 60 * 24 then "#{diff / 60 / 60}h"
      else                          "#{diff / 60 / 60 / 24}d"
      end
    end

    def detab(str, ts = 8)
      add = 0
      str.gsub(/\t/) {
        len = ts - ($~.begin(0) + add) % ts
        add += len - 1
        ' ' * len
      }
    end

    Z_SPACE = "\241\241"   # zen-kaku space

    def jsplit(str)
      str.sub(/\A[\s#{Z_SPACE}]+/oe, '').sub(/[\s#{Z_SPACE}]+\z/oe, '')\
          .split(/[\s#{Z_SPACE}]+/oe)
    end

  end

end   # module BitChannel
