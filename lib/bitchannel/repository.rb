#
# $Id$
#
# Copyright (c) 2003-2005 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'bitchannel/userconfig'
require 'bitchannel/filesystem'
require 'bitchannel/logger'
require 'bitchannel/killlist'
require 'bitchannel/textutils'
require 'bitchannel/exception'
require 'forwardable'

# "Wed Jun 23 15:39:58 2004" (UTC)
def Time.rcsdate(t)
  m = /\w{3} (\w{3})  ?(\d{1,2}) (\d{1,2}):(\d{1,2}):(\d{1,2}) (\d{4})/.match(t)
  raise ArgumentError, "not RCS date: #{t.inspect}" unless m
  Time.utc(m[6], m[1], m[2], m[3], m[4], m[5])
end

# "11 Jun 2004 10:39:56 -0000" (UTC, when reported by CVS)
def Time.diffdate(t)
  m = /(\d{1,2}) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2})/.match(t)
  raise ArgumentError, "not diff date: #{t.inspect}" unless m
  Time.utc(m[3], m[2], m[1], m[4], m[5], m[6])
end

# "2004/06/11 10:39:56" (UTC)
def Time.rcslogdate(t)
  m = %r<(\d{4})/(\d{2})/(\d{2}) (\d{2}):(\d{2}):(\d{2})>.match(t)
  raise ArgumentError, "not RCS log date: #{t.inspect}" unless m
  Time.utc(*m.captures)
end

# "2004-06-11 10:39:56 +0000" (UTC), CVS 1.12.9 or later
def Time.newcvslogdate(t)
  m = %r<(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2}) [+\-]\d{4}>.match(t)
  raise ArgumentError, "not new CVS log date: #{t.inspect}" unless m
  Time.utc(*m.captures)
end

def Time.cvslogdate(t)
  newcvslogdate(t)
rescue ArgumentError
  rcslogdate(t)
end

module BitChannel

  class Repository

    include ThreadLocalCache

    def initialize(hash, id = nil)
      @module_id = id
      UserConfig.parse(hash, 'repository') {|conf|
        @read_only_p = (conf[:read_only] ? true : false)
        conf.exclusive! :logfile, :logger
        logger = conf.get(:logfile) {|path| FileLogger.new(path) } ||
                 conf[:logger] ||
                 NullLogger.new
        cmd_path = conf.get_required(:cmd_path)
        fs_class = (conf[:fs_class] || DefaultFileSystem)
        wc_read_dir = fs_class.new(conf.get_required(:wc_read))
        unless read_only?
          conf.required! :wc_write
          wc_write_dir = fs_class.new(conf[:wc_write])
        else
          conf.ignore :wc_write
          wc_write_dir = nil
          @wc_write = nil
        end
        kill = KillList.load(DEFAULT_KILL_FILE)
        @wc_read  = CVSWorkingCopy.new(@module_id, wc_read_dir, cmd_path,
                                       logger, kill)
        @wc_write = CVSWorkingCopy.new(@module_id, wc_write_dir, cmd_path,
                                       logger, kill) unless read_only?
        @syntax = conf.get(:syntax_proc) {|pr| pr.call(self) }
        conf.required! :cachedir
        @link_cache = LinkCache.new(fs_class.new("#{conf[:cachedir]}/link".untaint))
        @revlink_cache = LinkCache.new(fs_class.new("#{conf[:cachedir]}/revlink".untaint))
        @notifier = conf[:notifier]
      }
    end

    attr_reader :module_id

    # internal use only
    attr_reader :link_cache
    attr_reader :revlink_cache

    def read_only?
      @read_only_p
    end

    attr_reader :syntax
    attr_writer :syntax   # FIXME: tmp

    def page_names
      @wc_read.cvs_Entries.keys
    end

    def pages
      page_names().map {|name| new_page(name) }
    end

    def orphan_pages
      pages().select {|page| page.orphan? }
    end

    def exist?(name)
      st = @wc_read.stat(name)
      st.file? and st.readable? and st.writable?
    rescue Errno::ENOENT
      return false
    end

    def page_must_exist(name)
      raise WrongPageName, "page not exist: #{name}" unless exist?(name)
    end
    private :page_must_exist

    def invalid?(name)
      st = @wc_read.stat(name)
      not st.file? or not st.readable?
    rescue Errno::ENOENT
      return false
    end

    def valid?(name)
      not invalid?(name)
    end

    def page_must_valid(name)
      raise WrongPageName, "wrong page name: #{name}" if invalid?(name)
    end
    private :page_must_valid

    def last_modified
      if read_only?
      then @wc_read.last_modified
      else @wc_write.last_modified
      end
    end

    def diff_from(org)
      @wc_read.chdir {|wc|
        return wc.cvs_diff_from(org)
      }
    end

    def [](name)
      page_must_exist name
      new_page(name)
    end

    def fetch(name)
      page_must_valid name
      new_page(name)
    end

    def updated(name, new_rev, new_text)
      update_linkcache name, @syntax.extract_links(new_text)
      notify name, new_rev
    end

    def updated_externally(name)
      @wc_read.chdir {|wc|
        wc.cvs_update name
      }
      text = @wc_read.read(name)
      @wc_write.chdir {|wc|
        wc.lock(name) {
          wc.cvs_update name
        }
      }
      update_linkcache name, @syntax.extract_links(text)
    rescue Errno::ENOENT
      raise PageNotFound, "no such page: #{name}"
    end

    private

    def new_page(name)
      table = update_tlc_slot('bitchannel.request.pages') { Hash.new }
      table[name] ||= PageEntity.new(self, name, @wc_read, @wc_write)
    end

    def update_linkcache(name, new_links)
      old_links = (@link_cache[name] || [])
      @link_cache[name] = new_links
      @revlink_cache.updating {|cache|
        (new_links - old_links).each do |n|
          cache.add_link n, name
        end
        (old_links - new_links).each do |n|
          cache.del_link n, name
        end
      }
    end

    def notify(name, new_rev)
      return unless @notifier
      # fork twice not to make zombie
      pid = fork {
        fork {
          sleep 2  # dirty hack: wait unlocking
          @wc_read.chdir {|wc|
            if new_rev == 1
              diffs = wc.cvs_diff_all(new_rev, name)
            else
              diffs = wc.cvs_diff(new_rev-1, new_rev, name)
            end
            @notifier.notify diffs
          }
        }
      }
      Process.waitpid pid
    end

  end   # class Repository


  class LinkCache

    def initialize(fs)
      @fs = fs
      @fs.mkdir '' unless @fs.directory?('')
      @locking = false
    end

    def clear
      @fs.rm_rf ''
      @fs.mkdir ''
    end

    def entries
      @fs.entries('')\
          .reject {|ent| /\,tmp\z/ =~ ent }\
          .select {|ent| @fs.file?(ent.untaint) }
    end

    def [](name)
      read_cache(name)
    end

    def []=(name, links)
      lock {
        write_cache name, links
      }
    end

    def add_link(name, lnk)
      links = (read_cache(name) || [])
      write_cache name, (links + [lnk]).uniq.sort
    end

    def del_link(name, lnk)
      links = (read_cache(name) || [])
      write_cache name, (links - [lnk]).uniq.sort
    end

    def updating
      lock {
        yield self
      }
    end

    private

    def lock
      if @locking
        yield
      else
        @fs.lock('') {
          begin
            @locking = true
            yield
          ensure
            @locking = false
          end
        }
      end
    end

    def read_cache(path)
      @fs.readlines(path).map {|line| line.chop.untaint }
    rescue Errno::ENOENT
      return nil
    end

    def write_cache(path, links)
      @fs.open_atomic_writer(path) {|f|
        links.each do |lnk|
          f.puts lnk
        end
      }
    end

  end   # class LinkCache


  module CVSRevision
    def cvsrev_to_i(rev, on1111 = 1)
      return on1111 if rev == '1.1.1.1'
      rev.slice(/\A1\.(\d+)\z/, 1).to_i
    end
  end


  class CVSWorkingCopy

    include ThreadLocalCache

    def initialize(id, fs, cmd, logger, killlist)
      @module_id = id
      @fs = fs
      @cvs_cmd = cmd
      @logger = logger
      @killlist = killlist
      @in_chdir = false
    end

    def dir
      @fs.prefix
    end

    def last_modified
      @fs.mtime('')
    end

    def chdir
      @fs.chdir('') {
        begin
          @in_chdir = true
          yield self
        ensure
          @in_chdir = false
        end
      }
    end

    extend Forwardable

    def_delegators "@fs", :exist?, :size, :stat, :read, :write, :lock

    def revision(name)
      rev, mtime = *cvs_Entries()[name]
      rev
    end

    def mtime(name)
      rev, mtime = *cvs_Entries()[name]
      mtime
    end

    def cvs_Entries
      update_tlc_slot('bitchannel.request.cvsEntries') {
        table = {}
        @fs.readlines('CVS/Entries').each do |line|
          next if /\AD/ =~ line
          ent, rev, mtime = *line.split(%r</>).values_at(1, 2, 3)
          table[@fs.decode(ent.untaint)] =
              [rev.split(%r<\.>).last.to_i, Time.rcsdate(mtime.untaint).getlocal]
        end
        table
      }
    end

    def readrev(name, rev)
      return 'This revision is removed by administrator' if @killlist[name].include?(rev)
      chdir {
        out, err = *cvs('up', '-p', "-r1.#{rev}", @fs.encode(name))
        return out
      }
    end

    def cvs_diff_all(rev2, name)
      d = diff('-uN', '-D2000-01-01 00:00:00', "-r1.#{rev2}", @fs.encode(name))
      d.kill if @killlist[name].overlap?(d.revision_range)
      d
    end

    def cvs_diff(rev1, rev2, name)
      d = diff('-u', "-r1.#{rev1}", "-r1.#{rev2}", @fs.encode(name))
      d.kill if @killlist[name].overlap?(d.revision_range)
      d
    end

    def cvs_diff_from(time)
      assert_chdir
      out, err = *cvs('diff', '-uN', "-D#{format_time_cvs(time)}")
      ds = Diff.parse_diffs(@fs, @module_id, out)
      ds.each do |d|
        d.kill if @killlist[d.page_name].overlap?(d.revision_range)
      end
      ds
    end

    private

    def format_time_cvs(time)
      sprintf('%04d-%02d-%02d %02d:%02d:%02d',
              time.year, time.month, time.mday,
              time.hour, time.min, time.sec)
    end

    def diff(*options)
      assert_chdir
      out, err = *cvs('diff', *options)
      Diff.parse(@fs, @module_id, out)
    end

    class Diff
      extend CVSRevision

      def Diff.parse_diffs(fs, mod, out)
        chunks = out.split(/^Index: /)
        chunks.shift
        chunks.map {|c| parse(fs, mod, c) }
      end

      def Diff.parse(fs, mod, chunk)
        meta = chunk.slice!(/\A.*?(?=^@@|\z)/m).to_s
        file = meta.slice(/\A(?:Index:)?\s*(\S+)/, 1).strip
        if /---/ !~ meta
          # empty new file.
          now = Time.now
          return new(mod, fs.decode(file), 0, now, 1, now, chunk)
        end
        _, stime, srev = *meta.slice(/^\-\-\- .*/).split("\t", 3)
        _, dtime, drev = *meta.slice(/^\+\+\+ .*/).split("\t", 3)
        new(mod,
            fs.decode(file),
            cvsrev_to_i(srev.to_s), Time.diffdate(stime).getlocal,
            cvsrev_to_i(drev), Time.diffdate(dtime).getlocal,
            chunk)
      end

      def initialize(mod, page, srev, stime, drev, dtime, diff)
        @module = mod
        @page_name = page
        @rev1 = srev
        @time1 = stime
        @rev2 = drev
        @time2 = dtime
        @diff = diff
        @killed = false
      end

      attr_reader :module
      attr_reader :page_name
      attr_reader :rev1
      attr_reader :time1
      attr_reader :rev2
      attr_reader :time2

      def diff
        @killed ? 'This revision is removed by administrator' : @diff
      end

      def original_diff
        @diff
      end

      def revision_range
        (@rev1 || 0) .. @rev2
      end

      def kill
        @killed = true
      end
    end

    public

    def cvs_log(name, rev)
      assert_chdir
      out, err = *cvs('log', "-r1.#{rev}", @fs.encode(name))
      log = Log.parse_logs(out)[0]
      log.kill if @killlist[name].include?(log.revision)
      log
    end

    def cvs_logs(name)
      assert_chdir
      out, err = *cvs('log', @fs.encode(name))
      logs = Log.parse_logs(out)
      kill = @killlist[name]
      logs.each do |log|
        log.kill if kill.include?(log.revision)
      end
      logs
    end

    class Log
      extend CVSRevision

      def Log.parse_logs(str)
        logs = str.split(/^----------------------------/)
        logs.shift  # remove header
        logs.last.slice!(/\A={8,}/)
        logs.map {|s| parse(s.strip) }.reject {|log| log.revision.nil? }
      end

      def Log.parse(str)
        rline, dline, *msg = *str.to_a
        new(cvsrev_to_i(rline.slice(/\Arevision (1(?:\.\d+)+)\s/, 1), nil),
            Time.cvslogdate(dline.slice(/date: (.*?);/, 1)).getlocal,
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
        @killed = false
      end

      attr_reader :revision
      attr_reader :date
      attr_reader :n_added
      attr_reader :n_removed
      attr_reader :log

      def killed?
        @killed
      end

      def kill
        @killed = true
      end
    end

    public

    def cvs_annotate(name)
      assert_chdir
      out, err = *cvs('annotate', *[ann_F(), @fs.encode(name)].compact)
      parse_annotation(name, out)
    end

    def cvs_annotate_rev(name, rev)
      assert_chdir
      out, err = *cvs('annotate', *[ann_F(), "-r1.#{rev}", @fs.encode(name)].compact)
      parse_annotation(name, out)
    end

    private

    def parse_annotation(name, out)
      kill = @killlist[name]
      out.map {|line|
        revstr, content = line.split(': ', 2)
        rev = revstr.slice(/1\.(\d+)/, 1).to_i
        AnnotateLine.new(name, rev, content.rstrip, kill.include?(rev))
      }
    end

    def ann_F
      (cvs_version() >= '001.011.002') ? '-F' : nil
    end

    class AnnotateLine
      def initialize(name, rev, line, killed)
        @name = name
        @revision = rev
        @line = line
        @killed = killed
      end

      attr_reader :name
      attr_reader :revision

      def line
        @killed ? '' : @line
      end

      def original_line
        @line
      end

      def killed?
        @killed
      end
    end

    public

    def merge(name, origrev, new_text)
      write name, new_text
      out, err = *cvs('up', '-ko', "-j1.#{origrev}", '-jHEAD', @fs.encode(name))
      if /conflicts during merge/ =~ err
        log "conflict: #{name}"
        merged = read(name)
        rev = revision(name)
        # prevent next writer from conflict
        @fs.unlink name; cvs_update_A name
        raise EditConflict.new('conflict found', merged, rev)
      end
    end

    def cvs_add(name)
      assert_chdir
      cvs 'add', '-kb', @fs.encode(name)
    end

    def cvs_checkin(name, log)
      assert_chdir
      cvs 'ci', '-m', log, @fs.encode(name)
    end

    def cvs_update_A(name)
      assert_chdir
      cvs 'up', '-A', @fs.encode(name)
    end

    def cvs_update(name)
      assert_chdir
      cvs 'up', @fs.encode(name)
    end

    def cvs(*args)
      execute(ignore_status_p(args[0]), @cvs_cmd, '-f', '-q', *args)
    end

    private

    def cvs_version
      update_tlc_slot('bitchannel.process.cvs_version') {
        assert_chdir
        # sould handle "1.11.1p1" like version number??
        out, err = *cvs('--version')
        verdigits = out.slice(/\d+\.\d+\.\d+/).split(/\./).map {|n| n.to_i }
        sprintf((['%03d'] * verdigits.length).join('.'), *verdigits)
      }
    end

    def ignore_status_p(cmd)
      cmd == 'diff'
    end

    def execute(ignore_status, *cmd)
      log %Q[exec: "#{cmd.join('", "')}"]
      popen3(ignore_status, *cmd) {|stdin, stdout, stderr|
        stdin.close
        return stdout.read, stderr.read
      }
    end

    def popen3(ignore_status, *cmd)
      child_stdin,   parent_stdin = *IO.pipe
      parent_stdout, child_stdout = *IO.pipe
      parent_stderr, child_stderr = *IO.pipe
      pid = Process.fork {
        parent_stdin.close
        parent_stdout.close
        parent_stderr.close
        STDIN.reopen child_stdin; child_stdin.close
        STDOUT.reopen child_stdout; child_stdout.close
        STDERR.reopen child_stderr; child_stderr.close
        exec(*cmd)
      }
      child_stdin.close
      child_stdout.close
      child_stderr.close
      begin
        parent_stdin.sync = true
        return yield(parent_stdin, parent_stdout, parent_stderr)
      ensure
        [parent_stdin, parent_stdout, parent_stderr].each do |f|
          f.close unless f.closed?
        end
        dummy, status = *Process.waitpid2(pid)
        if status.exitstatus != 0 and not ignore_status
          raise CommandFailed.new("Command failed: #{cmd.join ' '}", status)
        end
      end
    end

    def log(msg)
      @logger.log @module_id, msg
    end

    def assert_chdir
      raise "call in chdir" unless @in_chdir
    end

  end


  class PageEntity

    include TextUtils

    def initialize(repository, name, wc_read, wc_write)
      @repository = repository
      @name = name
      @wc_read = wc_read
      @wc_write = wc_write

      # cache
      @mtime = nil
      @mtimes = []
      @source = nil
      @revision = nil
      @links = nil
      @revlinks = nil
    end

    attr_reader :repository
    attr_reader :name

    def syntax
      @repository.syntax
    end

    def read_only?
      @repository.read_only?
    end

    def orphan?
      revlinks().empty?
    end

    def size
      @wc_read.size(@name)
    end

    def mtime(rev = nil)
      unless rev
        @mtime ||= @wc_read.mtime(@name)
      else
        return @mtimes[rev] if @mtimes[rev]
        @wc_read.chdir {|wc|
          return @mtimes[rev] = wc.cvs_log(@name, rev).date
        }
      end
    end

    def revision
      @revision ||= @wc_read.revision(@name)
    end

    def source(rev = nil)
      if rev
      then @wc_read.readrev(@name, rev)
      else @source = @wc_read.read(@name)
      end
    end

    def logs
      @wc_read.chdir {|wc|
        return wc.cvs_logs(@name)
      }
    end

    def diff(rev1, rev2)
      @wc_read.chdir {|wc|
        return wc.cvs_diff(rev1, rev2, @name)
      }
    end

    def annotate(rev = nil)
      @wc_read.chdir {|wc|
        if rev
          return wc.cvs_annotate_rev(name, rev)
        else
          return wc.cvs_annotate(name)
        end
      }
    end

    def links
      @links ||=
          (@repository.link_cache[@name] ||= @repository.syntax.extract_links(source()))
    end

    def revlinks
      @revlinks ||=
          (@repository.revlink_cache[@name] ||= collect_revlinks())
    end

    def collect_revlinks
      @repository.pages\
          .select {|page| page.links.include?(@name) }\
          .map {|page| page.name }
    end
    private :collect_revlinks

    def checkin(origrev, new_text)
      raise 'repository is read only' if @repository.read_only?
      new_rev = nil
      @wc_write.chdir {|wc|
        wc.lock(@name) {
          if wc.exist?(@name)
            if origrev
              wc.merge @name, origrev, new_text
              wc.cvs_checkin @name, "auto checkin: origrev=#{origrev} (merged)"
            else
              wc.write @name, new_text
              wc.cvs_checkin @name, "auto checkin: origrev=#{origrev}"
            end
          else
            wc.write @name, new_text
            wc.cvs_add @name
            wc.cvs_checkin @name, 'auto checkin: new file'
          end
          new_rev = wc.revision(@name)
        }
      }
      @wc_read.chdir {|wc|
        wc.cvs_update @name
      }
      @repository.updated @name, new_rev, new_text
    end

    def edit
      raise 'repository is read only' if @repository.read_only?
      new_rev = nil
      new_text = nil
      @wc_write.chdir {|wc|
        wc.lock(@name) {
          wc.cvs_update_A @name
          new_text = yield(wc.read(@name))
          wc.write @name, new_text
          wc.cvs_checkin @name, 'auto checkin'
          new_rev = wc.revision(@name)
        }
      }
      @wc_read.chdir {|wc|
        wc.cvs_update @name
      }
      @repository.updated @name, new_rev, new_text
    end
  
  end   # class PageEntity

end   # module BitChannel
