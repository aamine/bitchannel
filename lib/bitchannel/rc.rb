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
  @lang = 'ja'
  @resources = {}

  def BitChannel.lang
    @lang
  end

  def BitChannel.lang=(lang)
    raise ArgumentError, "not supported language: #{lang}" \
        unless @resources.key?(lang)
    @lang = lang
  end

  def BitChannel.gettext(key)
    table = @resources[@lang] or
        raise ResourceError, "resource not exist: #{@lang}"
    table[key]
  end
end

def gettext(key)
  ::BitChannel.gettext(key)
end

require 'bitchannel/rc/ja'
require 'bitchannel/rc/en'
