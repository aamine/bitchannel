#
# $Id$
#
# Copyright (C) 2003 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.
#

require 'wikitik/textutils'
require 'wikitik/exception'
require 'time'

module Wikitik

  class Repository

    include TextUtils

    def initialize(config, args)
      @config = config
      t = Hash.new {|h,k|
        raise ConfigError, "Config Error: not set: repository.#{k}"
      }
      t.update args
      @cvs_cmd  = t[:cmd_path]; t.delete(:cmd_path)
      @wc_read  = t[:wc_read];  t.delete(:wc_read)
      @wc_write = t[:wc_write]; t.delete(:wc_write)
      t.each do |k,v|
        raise ConfigError, "Config Error: unknown key set: #{k}"
      end
    end

    def exist?(page_name)
      raise 'page_name == nil' unless page_name
      raise 'page_name == ""' if page_name.empty?
      File.exist?("#{@wc_read}/#{encode_filename(page_name)}")
    end

    def entries
      Dir.entries(@wc_read)\
          .select {|ent| File.file?("#{@wc_read}/#{ent}") }\
          .map {|ent| decode_filename(ent) }
    end

    def mtime(page_name, rev = nil)
      unless rev
        File.mtime("#{@wc_read}/#{encode_filename(page_name)}")
      else
        Dir.chdir(@wc_read) {
          out, err = cvs('log', "-r1.#{rev}", encode_filename(page_name))
          out.each do |line|
            if /\Adate: / === line
              return Time.parse(line.slice(/\Adate: (.*?);/, 1))
            end
          end
        }
        raise UnknownRCSLogFormat, "unknown RCS log format; given up"
      end
    end

    def [](page_name, rev = nil)
      unless rev
        File.read("#{@wc_read}/#{encode_filename(page_name)}")
      else
        Dir.chdir(@wc_read) {
          out, err = cvs('up', '-p', "-r1.#{rev}", encode_filename(page_name))
          return out
        }
      end
    end

    def revision(page_name)
      re = %r<\A/#{Regexp.quote(encode_filename(page_name))}/1>
      line = File.readlines("#{@wc_read}/CVS/Entries").detect {|s| re =~ s }
      return nil unless line   # file not checked in
      line.split(%r</>)[2].split(%r<\.>).last.to_i
    end

    # [[rev,logstr]]
    def getlog(page_name)
      Dir.chdir(@wc_read) {
        out, err = cvs('log', encode_filename(page_name))
        result = []
        curr = nil
        out.each do |line|
          case line
          when /\Arevision 1\.(\d+)\s/
            result.push(curr = [$1.to_i, line.strip])
          when /\Adate:/
            if curr
              curr[1] << ": #{line.slice(/date: (.*?;)/, 1)} #{line.slice(/lines:.*/)}".gsub(/\s+/, ' ')
              curr = nil
            end
          end
        end
        return result
      }
    end

    def diff(page_name, rev1, rev2)
      Dir.chdir(@wc_read) {
        out, err = cvs('diff', '-u', "-r1.#{rev1}", "-r1.#{rev2}", encode_filename(page_name))
        return out.sub(/\A.*^diff .*?\n/m, '')
      }
    end

    def reverse_links(page_name)
      File.readlines(revlink_cache(page_name)).map {|s| s.strip }[1..-1]
    rescue Errno::ENOENT
      return []
    end

    def num_revlinks(page_name)
      File.open(revlink_cache(page_name)) {|f|
        return f.gets.strip.to_i
      }
    rescue Errno::ENOENT
      return 0
    end

    def checkin(page_name, origrev, new_text)
      filename = encode_filename(page_name)
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
      update_revlink_cache page_name, new_text
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
      cvs 'ci', '-m', "auto checkin: origrev=#{origrev}", filename
    end

    def add_and_checkin(filename, new_text)
      File.open(filename, 'w') {|f|
        f.write new_text
      }
      cvs 'add', filename
      cvs 'ci', '-m', 'auto checkin: new file', filename
    end

    def cvs(*args)
      execute(@cvs_cmd, '-f', '-q', *args)
    end

def LOG(msg)
  File.open('../log', 'a') {|f|
    f.puts "#{Time.now.inspect}: #{msg}"
  }
end
    def execute(*cmd)
LOG %Q[exec: "#{cmd.join('", "')}"]
      popen3(*cmd) {|stdin, stdout, stderr|
        stdin.close
        return stdout.read, stderr.read
      }
    end

    def revlink_cache(page_name)
      "#{@config.revlink_cachedir}/#{encode_filename(page_name)}"
    end

    # FIXME: cannot handle link-is-removed case
    def update_revlink_cache(page_name, text)
      links = ToHTML.new(@config, self).extract_links(text)
      cachedir = @config.revlink_cachedir
      lock(cachedir) {
        Dir.mkdir cachedir unless File.directory?(cachedir)
        links.each do |link|
          cachefile = "#{cachedir}/#{encode_filename(link)}"
          if File.exist?(cachefile)
            revlinks = File.readlines(cachefile).map {|line| line.strip }
            revlinks.shift   # discard first line (number of lines)
          else
            revlinks = []
          end
          revlinks = (revlinks + [page_name]).uniq.sort
          File.open("#{cachefile},tmp", 'w') {|f|
            f.puts revlinks.size
            revlinks.each do |rev|
              f.puts rev
            end
          }
          File.rename "#{cachefile},tmp", cachefile
        end
      }
    end

    RETRY_MAX = 5

    def lock(path)
      failed = 0
      lock = path + ',wikitik,lock'
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
        failed += 1
        raise LockFailed, "cannot get lock for #{File.basename(path)}" \
            if failed > RETRY_MAX
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
      pid = Process.fork {
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
      pw[0].close
      pr[1].close
      pe[1].close
      pipes = [pw[1], pr[0], pe[0]]
      pw[1].sync = true
      begin
        result = yield(*pipes)
        dummy, status = Process.waitpid2(pid)
        raise CommandFailed.new("Command failed: #{cmd.join ' '}", status) \
            unless status.exitstatus == 0
        return result
      ensure
        pipes.each do |f|
          f.close unless f.closed?
        end
      end
    end

  end

end
