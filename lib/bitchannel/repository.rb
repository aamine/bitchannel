#
# $Id$
#
# Copyright (C) 2003 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.
#

require 'alphawiki/textutils'

module AlphaWiki

  class Repository

    include TextUtils

    def initialize(dir)
      @dir = dir
    end

    def [](page_name)
      File.read(real_path(page_name))
    end

    def checkin(page_name, origrev, content)
      lock(real_path(page_name)) {
        File.open(real_path(page_name), 'w') {|f|
          f.write content
        }
      }
    end

    private

    def real_path(page_name)
      "#{@dir}/#{escape_html(page_name)}"
    end

    def lock(path)
      lock = path + ',alphawiki,lock'
      begin
        Dir.mkdir(lock)
        begin
          yield
        ensure
          Dir.rmdir(lock)
        end
      rescue Errno::EEXIST
        if File.directory?(lock) and too_old?(ctime(lock))
          begin
            Dir.rmdir lock
          rescue Errno::ENOENT
            ;
          end
          retry
        end
        sleep 3
        retry
      end
    end

    def ctime(path)
      File.ctime(path)
    rescue Errno::ENOENT
      ;
    end

    def too_old?(t)
      Time.now.to_i - st.ctime > 15 * 60   # 15min
    end

  end

end
