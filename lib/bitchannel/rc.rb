#
# $Id$
#
# Copyright (C) 2003 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.
#

require "alphawiki/rc/#{@lang}"

module AlphaWiki
  def AlphaWiki.gettext(key)
    @resource[key]
  end
end
