#
# $Id$
#
# Copyright (C) 2003 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.
#

module Wikitik
  @lang = 'ja'
  @resources = {}

  def Wikitik.lang
    @lang
  end

  def Wikitik.lang=(lang)
    raise ArgumentError, "not supported language: #{lang}" \
        unless @resources.key?(lang)
    @lang = lang
  end

  def Wikitik.gettext(key)
    table = @resources[@lang] or
        raise ResourceError, "resource not exist: #{@lang}"
    table[key]
  end
end

def gettext(key)
  ::Wikitik.gettext(key)
end

require 'wikitik/rc/ja'
require 'wikitik/rc/en'
