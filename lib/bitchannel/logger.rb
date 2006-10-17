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

  class FileLogger
    include TextUtils

    def initialize(path)
      @path = path
    end

    def log(id, msg)
      File.open(@path, 'a') {|f|
        f.puts "#{format_time(Time.now)};#{$$}; #{module_id(id)}#{msg}"
      }
    end

    private

    def module_id(id)
      id ? "[#{id}] " : ''
    end
  end


  class NullLogger
    def log(id, msg)
    end
  end

end
