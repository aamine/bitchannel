#
# $Id$
#
# Copyright (C) 2003,2004 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'bitchannel/textutils'
require 'bitchannel/exception'
require 'time'
require 'fileutils'

module BitChannel

  module FilenameEncoding
    def encode_filename(name)
      # encode [A-Z] ?  (There are case-insensitive filesystems)
      name.gsub(/[^a-z\d]/in) {|c| sprintf('%%%02x', c[0]) }.untaint
    end

    def decode_filename(name)
      name.gsub(/%([\da-h]{2})/i) { $1.hex.chr }.untaint
    end
  end


  module LockUtils
    # This method locks write access.
    # Read only access is always allowed.
    def lock(path)
      n_retry = 5
      lock = path + ',bitchannel,lock'
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

  end


  class Repository
    include FilenameEncoding
    include LockUtils
    include TextUtils

    def initialize(args)
      args = args.dup
      def args.getopt(name)
        raise ConfigError, "Config Error: not set: repository.#{name}" \
            unless key?(name)
        delete(name).untaint
      end
      @cvs_cmd  = args.getopt(:cmd_path)
      @wc_read  = args.getopt(:wc_read)
      @wc_write = args.getopt(:wc_write)
      @logfile  = args.getopt(:logfile)
      cachedir  = args.getopt(:cachedir)
      args.each do |k,v|
        raise ConfigError, "Config Error: unknown key: repository.#{k}"
      end
      @link_cache = LinkCache.new("#{cachedir}/link", "#{cachedir}/revlink")
    end

    # internal use only
    attr_reader :link_cache

    def page_names
      Dir.entries(@wc_read)\
          .map {|ent| ent.untaint }\
          .select {|ent| File.file?("#{@wc_read}/#{ent}") }\
          .map {|ent| decode_filename(ent) }
    end

    alias entries page_names

    def orphan_pages
      page_names().select {|name| orphan?(name) }
    end

    def orphan?(page_name)
      revlinks(page_name).empty?
    end

    def exist?(page_name)
      raise 'page_name == nil' unless page_name
      raise 'page_name == ""' if page_name.empty?
      File.file?("#{@wc_read}/#{encode_filename(page_name)}")
    end

    def invalid?(page_name)
      st = File.stat("#{@wc_read}/#{encode_filename(page_name)}")
      not st.file? or not st.readable?
    rescue Errno::ENOENT
      return false
    end

    def valid?(page_name)
      not invalid?(page_name)
    end

    def size(page_name)
      page_must_valid page_name
      File.size("#{@wc_read}/#{encode_filename(page_name)}")
    end

    def mtime(page_name, rev = nil)
      page_must_valid page_name
      page_must_exist page_name
      unless rev
        rev, mtime = *cvs_Entries()[page_name]
        mtime
      else
        Dir.chdir(@wc_read) {
          out, err = cvs('log', "-r1.#{rev}", encode_filename(page_name))
          dateline = out.detect {|line| /\Adate: / =~ line } or
              raise UnknownRCSLogFormat, "unknown RCS log format; given up"
          return Time.parse(line.slice(/\Adate: (.*?);/, 1))
        }
      end
    end

    def revision(page_name)
      page_must_valid page_name
      page_must_exist page_name
      rev, mtime = *cvs_Entries()[page_name]
      rev
    end

    def [](page_name, rev = nil)
      page_must_valid page_name
      unless rev
        File.read("#{@wc_read}/#{encode_filename(page_name)}")
      else
        page_must_exist page_name
        Dir.chdir(@wc_read) {
          out, err = cvs('up', '-p', "-r1.#{rev}", encode_filename(page_name))
          return out
        }
      end
    end

    def fetch(page_name, rev = nil)
      self[page_name, rev]
    rescue Errno::ENOENT
      return yield
    end

    def logs(page_name)
      page_must_valid page_name
      page_must_exist page_name
      Dir.chdir(@wc_read) {
        out, err = cvs('log', encode_filename(page_name))
        logs = out.split(/^----------------------------/)
        logs.shift  # remove header
        logs.last.slice!(/\A={8,}/)
        return logs.map {|str| Log.parse(str.strip) }
      }
    end

    class Log
      def Log.parse(str)
        rline, dline, *msg = *str.to_a
        new(rline.slice(/\Arevision 1\.(\d+)\s/, 1).to_i,
            Time.parse(dline.slice(/date: (.*?;)/, 1)),
            dline.slice(/lines: \+(\d+)/, 1).to_i,
            dline.slice(/lines:(?: \+(?:\d+))? -(\d+)/, 1).to_i,
            msg.join(''))
      end

      def initialize(rev, date, add, rem, msg)
        @revision = rev
        @date = date
        @n_added = add
        @n_removed = rem
        @log = msg
      end

      attr_reader :revision
      attr_reader :date
      attr_reader :n_added
      attr_reader :n_removed
      attr_reader :log
    end

    def diff(page_name, rev1, rev2)
      page_must_valid page_name
      page_must_exist page_name
      Dir.chdir(@wc_read) {
        out, err = cvs('diff', '-u', "-r1.#{rev1}", "-r1.#{rev2}", encode_filename(page_name))
        return out.sub(/\A.*^diff .*?\n/m, '')
      }
    end

    def annotate(page_name, rev = nil)
      page_must_valid page_name
      page_must_exist page_name
      Dir.chdir(@wc_read) {
        optF = (cvs_version() >= '001.011.002') ? '-F' : nil
        revopt = (rev ? "-r1.#{rev}" : nil)
        opts = [optF, revopt, encode_filename(page_name)].compact
        out, err = cvs('annotate', *opts)
        return out.gsub(/^.*?:/) {|s| sprintf('%4s', s.slice(/\.(\d+)/, 1)) }
      }
    end

    def links(page_name)
      cache = @link_cache.linkcache(page_name)
      return cache if cache
      result = extract_links(self[page_name])
      @link_cache.set_linkcache page_name, result
      result
    end

    def revlinks(page_name)
      cache = @link_cache.revlinkcache(page_name)
      return cache if cache
      result = collect_revlinks(page_name)
      @link_cache.set_revlinkcache page_name, result
      result
    end

    def edit(page_name)
      page_must_valid page_name
      page_must_exist page_name
      filename = encode_filename(page_name)
      Dir.chdir(@wc_write) {
        lock(filename) {
          cvs 'up', '-A', filename
          text = yield(File.read(filename))
          File.open(filename, 'w') {|f|
            f.write text
          }
          cvs 'ci', '-m', "edit checkin", filename
        }
      }
      Dir.chdir(@wc_read) {
        cvs 'up', '-A', filename
      }
    end

    def checkin(page_name, origrev, new_text)
      page_must_valid page_name
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
      @link_cache.update_cache_for page_name,
          ToHTML.extract_links(new_text, self)
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

    def cvs_version
      # sould handle "1.11.1p1" like version number??
      out, err = *cvs('--version')
      verdigits = out.slice(/\d+\.\d+\.\d+/).split(/\./).map {|n| n.to_i }
      sprintf((['%03d'] * verdigits.length).join('.'), *verdigits)
    end

    def cvs(*args)
      execute(ignore_status_p(args[0]), @cvs_cmd, '-f', '-q', *args)
    end

    def ignore_status_p(cmd)
      cmd == 'diff'
    end

    def execute(ignore_status, *cmd)
      log %Q[exec: "#{cmd.join('", "')}"]
      popen3(ignore_status, *cmd) {|stdin, stdout, stderr|
        stdin.close
        out = stdout.read
        err = stderr.read
        log "got stderr (#{cmd.join(' ')}):\n#{err}" unless err.empty?
        return out, err
      }
    end

    def popen3(ignore_status, *cmd)
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
        return yield(*pipes)
      ensure
        pipes.each do |f|
          f.close unless f.closed?
        end
        dummy, status = Process.waitpid2(pid)
        if status.exitstatus != 0 and not ignore_status
          raise CommandFailed.new("Command failed: #{cmd.join ' '}", status)
        end
      end
    end

    def log(msg)
      return unless @logfile
      File.open(@logfile, 'a') {|f|
        begin
          f.flock File::LOCK_EX
          f.puts "#{format_time(Time.now)};#{$$}; #{msg}"
          f.flush
        ensure
          f.flock File::LOCK_UN
        end
      }
    end

    def page_must_valid(name)
      raise WrongPageName, "wrong page name: #{name}" if invalid?(name)
    end

    def page_must_exist(name)
      File.open("#{@wc_read}/#{encode_filename(name)}", 'r') {
        ;
      }
    end

    def cvs_Entries
      read_Entries("#{@wc_read}/CVS/Entries")
    end

    def read_Entries(filename)
      table = {}
      File.readlines(filename).each do |line|
        next if /\AD/ =~ line
        ent, rev, mtime = *line.split(%r</>).values_at(1, 2, 3)
        table[decode_filename(ent).untaint] =
            [rev.split(%r<\.>).last.to_i, cvstimestamp(mtime).untaint]
      end
      table
    end

    def cvstimestamp(str)
      Time.parse(str.sub(/\d+$/) {|y| ' GMT ' + y }).localtime
    end

    def extract_links(page_text)
      ToHTML.extract_links(page_text, self)
    end

    def collect_revlinks(page_name)
      page_names().select {|name|
        ToHTML.extract_links(self[name], self).include?(page_name)
      }
    end
  end   # class Repository


  class LinkCache
    include FilenameEncoding
    include LockUtils

    def initialize(linkcachedir, revlinkcachedir)
      @linkcachedir = linkcachedir
      @revlinkcachedir = revlinkcachedir
    end

    def clear
      FileUtils.rm_rf @linkcachedir
      FileUtils.rm_rf @revlinkcachedir
    end

    def linkcache(page_name)
      read_cache(linkcache_file(page_name))
    end

    def revlinkcache(page_name)
      read_cache(revlinkcache_file(page_name))
    end

    def update_cache_for(page_name, links)
      set_linkcache page_name, links
      update_revlinkcache_for page_name, links
    end

    def set_linkcache(page_name, links)
      lock(@linkcachedir) {|cachedir|
        Dir.mkdir cachedir unless File.directory?(cachedir)
        write_cache linkcache_file(page_name), links
      }
    end

    def set_revlinkcache(page_name, links)
      lock(@revlinkcachedir) {|cachedir|
        Dir.mkdir cachedir unless File.directory?(cachedir)
        write_cache revlinkcache_file(page_name), links
      }
    end

    private

    def update_revlinkcache_for(page_name, links)
      linktbl = {}
      links.each do |page|
        linktbl[page] = true
      end
      lock(@revlinkcachedir) {|cachedir|
        Dir.mkdir cachedir unless File.directory?(cachedir)
        foreach_file(cachedir) do |cachefile|
          if linktbl.delete(decode_filename(File.basename(cachefile)))
            add_linkcache_entry cachefile, page_name
          else
            remove_linkcache_entry cachefile, page_name
          end
        end
        linktbl.each_key do |link|
          add_linkcache_entry revlinkcache_file(link), page_name
        end
      }
    end

    def linkcache_file(page_name)
      "#{@linkcachedir}/#{encode_filename(page_name)}"
    end

    def revlinkcache_file(page_name)
      "#{@revlinkcachedir}/#{encode_filename(page_name)}"
    end

    def add_linkcache_entry(path, page_name)
      links = (read_cache(path) || [])
      write_cache path, (links + [page_name]).uniq.sort
    end

    def remove_linkcache_entry(path, page_name)
      links = (read_cache(path) || [])
      write_cache path, (links - [page_name]).uniq.sort
    end

    def read_cache(path)
      File.readlines(path).map {|line| line.strip.untaint }
    rescue Errno::ENOENT
      return nil
    end

    def write_cache(path, links)
      tmp = "#{path},tmp"
      File.open(tmp, 'w') {|f|
        links.each do |lnk|
          f.puts lnk
        end
      }
      File.rename tmp, path
    ensure
      File.unlink tmp if File.exist?(tmp)
    end

    def foreach_file(dir, &block)
      Dir.entries(dir).map {|ent| "#{dir}/#{ent}".untaint }\
          .select {|path| File.file?(path) }.each(&block)
    end

  end   # class LinkCache

end
