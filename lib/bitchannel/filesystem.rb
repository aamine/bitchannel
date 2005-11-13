#
# $Id$
#
# Copyright (c) 2003-2005 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'fileutils'

module BitChannel

  class FileSystem

    include FileUtils

    def initialize(prefix)
      @prefix = prefix
    end

    attr_reader :prefix

    def real_path(rel)
      "#{@prefix}/#{encode(rel)}".chomp('/')
    end

    def open(rel, mode = 'r', &block)
      File.open(real_path(rel), mode, &block)
    end

    def read(rel)
      File.read(real_path(rel))
    end

    def readlines(rel)
      File.readlines(real_path(rel))
    end

    def write(rel, str)
      open_atomic_writer(rel) {|f|
        f.write str
      }
    end

    def mtime(rel)
      File.mtime(real_path(rel))
    end

    def stat(rel)
      File.stat(real_path(rel))
    end

    def size(rel)
      File.size(real_path(rel))
    end

    def chdir(rel, &block)
      Dir.chdir(real_path(rel), &block)
    end

    def mkdir(rel)
      Dir.mkdir real_path(rel)
    end

    def rmdir(rel)
      Dir.rmdir real_path(rel)
    end

    def rm_rf(rel)
      FileUtils.rm_rf real_path(rel)
    end

    def entries(rel)
      Dir.entries(real_path(rel)).map {|s| decode(s) }
    end

    def file?(rel)
      File.file?(real_path(rel))
    end

    def directory?(rel)
      File.directory?(real_path(rel))
    end

    def exist?(rel)
      File.exist?(real_path(rel))
    end

    # Atomic write.
    # Process must lock REL before writing.
    def open_atomic_writer(rel, &block)
      path = real_path(rel)
      tmp = path + ',tmp'
      File.open(tmp, File::WRONLY|File::CREAT|File::EXCL, &block)
      File.rename tmp, path
    rescue Exception
      begin
        File.unlink tmp
      rescue
      end
    end

    # This method locks write access.
    # Read only access is always allowed.
    def lock(rel)
      n_retry = 5
      path = real_path(rel) + ',bitchannel,lock'
      begin
        Dir.mkdir path
        begin
          yield rel
        ensure
          Dir.rmdir path
        end
      rescue Errno::EEXIST
        if n_retry > 0
          sleep 3
          n_retry -= 1
          retry
        end
        raise LockFailed, "cannot lock #{real_path(rel)}"
      end
    end

    def encode(path)
      path
    end

    def decode(path)
      path
    end

  end


  class CaseSensitiveFileSystem < FileSystem
    def encode(path)
      path.split('/').map {|s|
        s.gsub(/[^a-zA-Z\d]/n) {|c| sprintf('%%%02x', c[0]) }
      }.join('/').untaint
    end

    def decode(path)
      path.split('/').map {|s|
        s.gsub(/%([\da-h]{2})/i) { $1.hex.chr }
      }.join('/').untaint
    end
  end


  class CaseInsensitiveFileSystem < FileSystem
    def encode(path)
      path.split('/').map {|s|
        s.gsub(/[^a-z\d]/n) {|c| sprintf('%%%02x', c[0]) }
      }.join('/').untaint
    end

    def decode(path)
      path.split('/').map {|s|
        s.gsub(/%([\da-h]{2})/i) { $1.hex.chr }
      }.join('/').untaint
    end
  end


  if /mswin|mingw|cygwin|emx/ =~ RUBY_PLATFORM
    DefaultFileSystem = CaseInsensitiveFileSystem
  else
    DefaultFileSystem = CaseSensitiveFileSystem
  end

end
