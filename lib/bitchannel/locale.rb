#
# $Id$
#
# Copyright (C) 2003,2004 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'bitchannel/exception'

module BitChannel
  class Locale
    @table = {}

    def Locale.declare_locale(key, loc)
      raise ArgumentError, "already declared locale: #{key}" if key?(key)
      @table[key.downcase] = loc
    end

    def Locale.get(key)
      @table[key.downcase] or raise ArgumentError, "no such locale: #{key}"
    end

    def Locale.key?(key)
      @table.key?(key.downcase)
    end

    def Locale.keys
      @table.keys.map {|k| k.downcase }
    end

    def initialize
      @rc = Hash.new {|h,k| raise ResourceError, "unknown resource key: #{k}" }
    end

    def rc_table
      @rc
    end
    private :rc_table

    def text(key)
      @rc[key]
    end

    def inspect
      "\#<#{self.class} #{name()}>"
    end
  end
end

require 'bitchannel/locale/ja'
require 'bitchannel/locale/en'
