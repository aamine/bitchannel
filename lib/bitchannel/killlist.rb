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

  class KillList

    def KillList.load(path)
      parse(File.readlines(path))
    rescue Errno::ENOENT
      return new()
    end

    def KillList.parse(lines)
      list = new()
      lineno = 0
      lines.each do |line|
        lineno += 1
        line = line.split('#', 2).first.to_s.strip
        next if line.empty?
        name, rangespec = *line.split(/\s+/, 2)
        list.add name, IntList.parse(rangespec)
      end
      list
    rescue IntListParseError => err
      raise KillListParseError, "killfile line #{lineno}: #{err.message}"
    end

    def initialize
      @list = Hash.new(IntList.new([]))
    end

    def add(name, range)
      @list[name] = range
    end

    def [](name)
      @list[name]
    end
  
  end


  class IntList
    def IntList.parse(spec)
      new(spec.split(',').map {|s|
        case s
        when /\A(\d+)\z/        then IntN.new($1.to_i)
        when /\A(\d+)-(\d+)\z/  then IntInterval.new($1.to_i, $2.to_i)
        else
          raise IntListParseError, "unknown format: #{s}"
        end
      })
    end

    def initialize(list)
      @list = list
    end

    def include?(n)
      @list.any? {|i| i.include?(n) }
    end

    def overlap?(r)
      @list.any? {|i| i.overlap?(r) }
    end
  end


  class IntN
    def initialize(n)
      @n = n
    end

    def include?(n)
      n == @n
    end

    def overlap?(r)
      r.include?(@n)
    end
  end


  class IntInterval
    def initialize(beg, _end)
      @begin, @end = *[beg, _end].sort
    end

    def include?(n)
      @begin <= n and n <= @end
    end

    def overlap?(r)
      if @begin < r.begin
      then @end >= r.begin
      else r.include?(@begin)
      end
    end
  end

end   # module BitChannel
