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
require 'alphawiki/exception'

module AlphaWiki

  class Repository

    include TextUtils

    def initialize(cvs, wc_read, wc_write)
      @cvs_cmd = cvs
      @wc_read = wc_read
      @wc_write = wc_write
    end

    def exist?(page_name)
      raise 'page_name == nil' unless page_name
      raise 'page_name == ""' if page_name.empty?
      File.exist?("#{@wc_read}/#{escape_html(page_name)}")
    end

    def [](page_name)
      File.read("#{@wc_read}/#{escape_html(page_name)}")
    end

    def revision(page_name)
      re = %r<\A/#{Regexp.quote(escape_html(page_name))}/1>
      line = File.readlines("#{@wc_read}/CVS/Entries").detect {|s| re =~ s }
      return nil unless line   # file not checked in
      line.split(%r</>)[2]
    end

    def checkin(page_name, origrev, new_text)
      filename = escape_html(page_name)
      Dir.chdir(@wc_write) {
        lock(filename) {
          if File.exist?(filename)
            update_and_checkin filename, origrev, new_text
          else
            add_and_checkin filename, new_text
          end
        }
      }
      Dir.chdir(@wc_read) {
        cvs 'up', '-A', filename
      }
    end

    private

    def update_and_checkin(filename, origrev, new_text)
      cvs 'up', (origrev ? "-r1.#{origrev}" : '-A'), filename
      File.open(filename, 'w') {|f|
        f.write new_text
      }
      if origrev
        out, err = *cvs('up', '-A', filename)
        if /conflicts during merge/ =~ err
          merged = File.read(filename)
          File.unlink filename   # prevent next writer from conflict
          cvs 'up', '-A', filename
          raise EditConflict.new('conflict found', merged)
        end
      end
      cvs 'ci', filename
    end

    def add_and_checkin(filename, new_text)
      File.open(filename, 'w') {|f|
        f.write new_text
      }
      cvs 'add', filename
      cvs 'ci', filename
    end

    def cvs(*args)
      execute(@cvs_cmd, *args)
    end

    def execute(*cmd)
      popen3(*cmd) {|stdin, stdout, stderr|
        return stdout.read, stderr.read
      }
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

    #
    # open3
    #

    def popen3(*cmd)
      pw = IO.pipe
      pr = IO.pipe
      pe = IO.pipe
      pid = fork {
        fork{
          pw[1].close
          STDIN.reopen(pw[0])
          pw[0].close

          pr[0].close
          STDOUT.reopen(pr[1])
          pr[1].close

          pe[0].close
          STDERR.reopen(pe[1])
          pe[1].close

          exec(*cmd)
        }
        exit!
      }
      pw[0].close
      pr[1].close
      pe[1].close
      pipes = [pw[1], pr[0], pe[0]]
      pw[1].sync = true

      dummy, status = Process.waitpid2(pid)
      raise CommandFailed, "Command failed: #{cmd.join ' '}" \
          unless status.exitstatus == 0

      begin
        return yield(*pipes)
      ensure
        pipes.each do |f|
          f.close unless f.closed?
        end
      end
    end

  end

end
