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

    def beautify_wikiname(name)
      name.gsub(/(.)([A-Z])/) { "#{$1} #{$2}" }
    end

    ESC = {
      '&' => '&amp;',
      '"' => '&quot;',
      '<' => '&lt;',
      '>' => '&gt;'
    }

    def escape_html( str )
      esc = ESC
      str.gsub(/[&"<>]/) {|s| esc[s] }
    end

  end

end   # module AlphaWiki
