#
# $Id$
#
# Copyright (C) 2003 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.
#

require 'wikitik/textutils'
require 'stringio'
require 'uri'

module Wikitik

  class ToHTML

    include TextUtils

    def initialize(config, repo)
      @config = config
      @repository = repo
      @indent_stack = [[0,'top']]
    end

    def compile(str)
      convert(StringIO.new(str))
    end

    private

    def convert( input, output = nil )
      @f = LineInput.new(input)
      @output = output || StringIO.new
      while @f.next?
        next_level true
      end
      output ? nil : @output.string
    end

    #
    # Block
    #

    BlankLine = Object.new
    def BlankLine.===(str)
      str.strip.empty?
    end

    def next_level( toplevel_p )
      case @f.peek
      when /\A={2,6}\s/    then caption @f.gets
      when /\A\s*\*\s/     then xlist 'ul'
      when /\A\s*\d*\.\s/  then xlist 'ol'
      when /\A\s*:\s/      then dl
      when BlankLine
        @f.skip_blank_lines
      else
        paragraph_cluster toplevel_p
        return
      end
    end

    def caption( line )
      level = line.slice(/\A(=+)\s/, 1).length
      str = line.sub(/\A=+/, '').strip
      puts "<h#{level}>#{escape_html(str)}</h#{level}>"
    end

    def paragraph_cluster( toplevel_p )
      push_indent(indent(@f.peek), 'pcluster') {
        while @f.next? and indent_same?(@f.peek)
          paragraph
          @f.skip_blank_lines
          while @f.next?
            return if /\A=/ === @f.peek
            return if indent_shallower?(@f.peek)
            if toplevel_p
              return if indent_same?(@f.peek) and function_line?(@f.peek)
              break if indent_same?(@f.peek)
            else
              break if indent_same?(@f.peek) and not function_line?(@f.peek)
            end
            case
            when function_line?(@f.peek) then next_level false
            when indent_deeper?(@f.peek) then pre
            else
              raise 'must not happen'
            end
            @f.skip_blank_lines
          end
        end
      }
    end

    def paragraph
      print '<p>'
      while line = @f.peek
        return if line.strip.empty?
        return if function_line?(line)
        return if indent_changed?(line)
        puts text(remove_current_indent(@f.gets))
      end
    ensure
      puts '</p>'
    end

    def xlist( type )
      puts "<#{type}>"
      mark_re = /\A\s*#{'\\' + @f.peek.slice(/\*|\d/).sub(/\d/, 'd\\.')}/
      push_indent(indent(@f.peek), 'xlist') {
        while @f.next?
          return if /\A=/ === @f.peek
          break if indent_shallower?(@f.peek)
          break unless mark_re === @f.peek
          li
          @f.skip_blank_lines
        end
      }
    ensure
      puts "</#{type}>"
    end

    def li
      print '<li>'
      @f.ungets remove_li_mark(@f.gets)
      paragraph_cluster false
    ensure
      puts '</li>'
    end

    def remove_li_mark( str )
      str.sub(/\*|\d+\./) {|s| ' ' * s.length }
    end

    def dl
      puts '<dl>'
      push_indent(indent(@f.peek), 'dl') {
        while @f.next?
          break if indent_shallower?(@f.peek)
          break unless /\A\s*:/ === @f.peek
          dt @f.gets
          @f.skip_blank_lines
          dd
          @f.skip_blank_lines
        end
      }
    ensure
      puts '</dl>'
    end

    def dt( line )
      puts "<dt>#{text(line.sub(/:/, '').strip)}</dt>"
    end

    def dd
      return unless @f.next?
      begin
        print '<dd>'
        paragraph_cluster false
      ensure
        puts '</dd>'
      end
    end

    def pre
      delayed_blanks = 0
      puts '<pre>'
      push_indent(indent(@f.peek), 'pre') {
        while @f.next?
          break if indent_shallower?(@f.peek)
          delayed_blanks.times do
            puts
          end
          delayed_blanks = 0
          puts preline(remove_current_indent(@f.gets))
          delayed_blanks = @f.skip_blank_lines
        end
      }
    ensure
      puts '</pre>'
    end

    def preline( line )
      escape_html(line)
    end

    #
    # Indent
    #

    def push_indent( n, label )
      raise "wrong indent stack status: ...#{@indent_stack.last},#{n}:#{label}"\
          unless n >= current_indent()
      raise "duplicated push: #{@indent_stack.last[1]}"\
          if @indent_stack.last[1] == label
      @indent_stack.push [n,label]
      yield
    ensure
      @indent_stack.pop
    end

    def current_indent
      @indent_stack.last[0]
    end

    def indent_same?( line )
      indent(line) == current_indent()
    end

    def indent_changed?( line )
      indent(line) != current_indent()
    end

    def indent_not_shallower?( line )
      indent(line) >= current_indent()
    end

    def indent_deeper?( line )
      indent(line) > current_indent()
    end

    def indent_shallower?( line )
      indent(line) < current_indent()
    end

    def remove_current_indent( line )
      detab(line)[current_indent()..-1]
    end

    def indent( line )
      detab(line.slice(/\A\s*/)).length
    end

    def detab( str, ts = 8 )
      add = 0
      str.gsub(/\t/) {
        len = ts - ($~.begin(0) + add) % ts
        add += len - 1
        ' ' * len
      }
    end

    def function_line?( line )
      /\A=+\s|\A\s*(\*|\d+\.|:)\s/ === line
    end

    #
    # Inline
    #

    WikiName = /\b(?:[A-Z][a-z0-9]+){2,}\b/n   # /\b/ requires `n' option
    ExplicitLink = /\[\[.*?\]\]/e
        # FIXME: `e' option does not effect in the final regexp.
    schemes = %w( http ftp )
    SeemsURL = /\b(?=#{Regexp.union(*schemes)}:)#{URI::PATTERN::X_ABS_URI}/xn
        # from uri/common.rb:URI.extract
    NeedESC = /[&"<>]/

    def text(str)
      esctable = TextUtils::ESC
      cgi_href = escape_html(@config.cgi_url)
      str.gsub(/(#{NeedESC})|(#{WikiName})|(#{ExplicitLink})|(#{SeemsURL})/on) {
        if ch = $1
          esctable[ch]
        elsif wikiname = $2
          href = escape_html(URI.escape(wikiname))
          link = escape_html(wikiname)
          q = (@repository.exist?(wikiname) ? '' : '?')
          %Q[<a href="#{cgi_href}?cmd=view;name=#{href}">#{q}#{link}</a>]
        elsif exlink = $3
          href = escape_html(URI.escape(exlink[2..-3]))
          link = escape_html(exlink[2..-3])
          q = (@repository.exist?(exlink[2..-3]) ? '' : '?')
          %Q[<a href="#{cgi_href}?cmd=view;name=#{href}">#{q}#{link}</a>]
        elsif url = $4
          if url[-1,1] == ')'   # special case
            url[-1,1] = ''
            %Q[<a href="#{escape_html(url)}">#{escape_html(url)}</a>)]
          else
            %Q[<a href="#{escape_html(url)}">#{escape_html(url)}</a>]
          end
        else
          raise 'must not happen'
        end
      }
    end

    #
    # I/O
    #

    def print( str )
      @output.print str
    end

    def puts( *args )
      @output.puts(*args)
    end

    class LineInput
      def initialize( f )
        @f = f
        @buf = []
      end

      def inspect
        "\#<#{self.class} file=#{@f.inspect} line=#{lineno()}>"
      end

      def lineno
        @f.lineno
      end

      def gets
        return nil unless @buf
        return @buf.pop unless @buf.empty?
        line = @f.gets
        unless line
          @buf = nil
          return nil
        end
        line.rstrip
      end

      def peek
        line = gets()
        ungets line if line
        line
      end

      def ungets( line )
        @buf.push line
      end

      def next?
        peek() ? true : false
      end

      def skip_blank_lines
        n = 0
        while line = gets()
          unless line.strip.empty?
            ungets line
            return n
          end
          n += 1
        end
        n
      end
    end

  end

end   # module Wikitik


if $0 == __FILE__
  require 'getopts'

  def usage( status )
    (status == 0 ? $stdout : $stderr).print(<<EOS)
Usage: #{File.basename($0)} [file file...] > output.html
EOS
    exit status
  end

  def main
    ok = getopts(nil, 'help')
    usage(0) if $OPT_help
    usage(1) unless ok
    c = Wikitik::ToHTML.new
    c.convert(ARGF, STDOUT)
  end

  main
end
