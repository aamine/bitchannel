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

    def entries
      Dir.entries(@wc_read)\
          .select {|ent| File.file?("#{@wc_read}/#{ent}") }\
          .map {|ent| decode_filename(ent) }
    end

    def exist?(page_name)
      raise 'page_name == nil' unless page_name
      raise 'page_name == ""' if page_name.empty?
      File.exist?("#{@wc_read}/#{encode_filename(page_name)}")
    end

    def size(page_name)
      File.size("#{@wc_read}/#{encode_filename(page_name)}")
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

    def annotate(page_name, rev = nil)
      Dir.chdir(@wc_read) {
        if rev
          out, err = cvs('ann', '-F', "-r1.#{rev}", encode_filename(page_name))
        else
          out, err = cvs('ann', '-F', encode_filename(page_name))
        end
        return out.map {|line| line.sub(/\(\S+\s*/, '(') }.join('').strip
      }
    end

    def links(page_name)
      read_linkcache(link_cache(page_name))
    end

    def reverse_links(page_name)
      read_linkcache(revlink_cache(page_name))
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
      links = ToHTML.new(@config, self).extract_links(new_text)
      update_link_cache page_name, links
      update_revlink_cache page_name, links
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
      cvs 'add', '-kb', filename
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

    def update_link_cache(page_name, links)
      lock(@config.link_cachedir) {|cachedir|
        Dir.mkdir cachedir unless File.directory?(cachedir)
        File.open(link_cache(page_name) + ',tmp', 'w') {|f|
          links.each do |lnk|
            f.puts lnk
          end
        }
      }
    end

    def link_cache(page_name)
      "#{@config.link_cachedir}/#{encode_filename(page_name)}"
    end

    def update_revlink_cache(page_name, links)
      linktbl = {}
      links.each do |page|
        linktbl[page] = true
      end
      lock(@config.revlink_cachedir) {|cachedir|
        Dir.mkdir cachedir unless File.directory?(cachedir)
        foreach_file(cachedir) do |cachefile|
          if linktbl.delete(decode_filename(File.basename(cachefile)))
            add_linkcache_entry cachefile, page_name
          else
            remove_linkcache_entry cachefile, page_name
          end
        end
        linktbl.each_key do |link|
          add_linkcache_entry revlink_cache(link), page_name
        end
      }
    end

    def revlink_cache(page_name)
      "#{@config.revlink_cachedir}/#{encode_filename(page_name)}"
    end

    def add_linkcache_entry(path, page_name)
      links = read_linkcache(path)
      write_linkcache path, (links + [page_name]).uniq.sort
    end

    def remove_linkcache_entry(path, page_name)
      links = read_linkcache(path)
      write_linkcache path, (links - [page_name]).uniq.sort
    end

    def read_linkcache(path)
      File.readlines(path).map {|line| line.strip }
    rescue Errno::ENOENT
      return []
    end

    def write_linkcache(path, links)
      File.open("#{path},tmp", 'w') {|f|
        links.each do |lnk|
          f.puts lnk
        end
      }
      File.rename "#{path},tmp", path
    end

    def foreach_file(dir, &block)
      Dir.entries(dir).map {|ent| "#{dir}/#{ent}" }\
          .select {|path| File.file?(path) }.each(&block)
    end

    # This method locks write access.
    # Read only access is always allowed.
    def lock(path)
      n_retry = 5
      lock = path + ',wikitik,lock'
      begin
        Dir.mkdir(lock)
        begin
          yield path
        ensure
          Dir.rmdir(lock)
        end
      rescue Errno::EEXIST
        if n_retry > 0
          sleep 3
          n_retry -= 1
          retry
        end
        raise LockFailed, "cannot get lock for #{File.basename(path)}"
      end
    end

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

    def encode_filename(name)
      # encode [A-Z] ?  (There are case-insensitive filesystems)
      name.gsub(/[^a-z\d]/in) {|c| sprintf('%%%02x', c[0]) }
    end

    def decode_filename(name)
      name.gsub(/%([\da-h]{2})/i) { $1.hex.chr }
    end

  end

end
