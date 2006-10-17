#
# $Id$
#
# Copyright (C) 2003-2006 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

module BitChannel

  module ThreadLocalCache

    def ThreadLocalCache.invalidate
      t = Thread.current['ThreadLocalCache_storage'] or return
      t.clear
    end

    def ThreadLocalCache.invalidate_slot_class(c)
      t = Thread.current['ThreadLocalCache_storage'] or return
      re = /\A#{Regexp.quote(c)}\./
      t.each_key do |name|
        t.delete name if re =~ name
      end
    end

    def ThreadLocalCache.invalidate_slot(name)
      t = Thread.current['ThreadLocalCache_storage'] or return
      t.delete name
    end

    private

    def update_tlc_slot(name)
      t = (Thread.current['ThreadLocalCache_storage'] ||= {})
      if t.key?(name)
      then t[name]
      else t[name] = yield
      end
    end
  
  end

end
