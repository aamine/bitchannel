#
# $Id$
#
# Copyright (C) 2003 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'bitchannel/textutils'
require 'stringio'
require 'uri'

module BitChannel

  class ToHTML

    include TextUtils

    def initialize(config, repo)
      @config = config
      @repository = repo
      @interwikinames = nil
    end

    def compile(str, page_name)
      @f = LineInput.new(StringIO.new(str))
      @page_name = page_name
      @result = ''
      @indent_stack = [0]
      @internal_links = []
      do_compile
      @result
    end

    DUMMY_CONFIG = Object.new
    def DUMMY_CONFIG.html_url?
      true
    end

    def ToHTML.extract_links(str, repo)
      new(DUMMY_CONFIG, repo).extract_links(str)
    end

    def extract_links(str)
      compile(str, ' (dummy) ')   # page name never includes ' ' in BitChannel
      @internal_links
    end

    private

    #
    # Block
    #

    CAPTION = /\A[=!]{2,6}/
    UL = /\A\s*\*/
    OL = /\A\s*\#|\A\s*\(\d+\)/
    DL = /\A\s*:/
    CITE = /\A""/
    TABLE = /\A\|\|/
    PRE = /\A\{\{\{/

    def do_compile
      while @f.next?
        case @f.peek
        when CAPTION  then caption @f.gets
        when UL       then ul
        when OL       then ol
        when DL       then dl
        when CITE     then cite
        when TABLE    then table
        when PRE      then pre
        else
          if line.strip.empty?
            @f.gets
          else
            paragraph
          end
        end
      end
    end

    def caption(line)
      level = line.slice(/\A([=!]+)/, 1).length
      str = line.sub(/\A[=!]+/, '').strip
      puts "<h#{level}>#{escape_html(str)}</h#{level}>"
    end

    def paragraph
      print '<p>'
      @f.until_match(/#{CAPTION}|#{UL}|#{OL}|#{DL}|#{CITE}|#{TABLE}|#{PRE}/o) do |line|
        break if line.strip.empty?
        puts text(line.strip)
      end
      puts '</p>'
    end

    def ul
      xlist 'ul', UL
    end

    def ol
      xlist 'ol', OL
    end

    def xlist(type, mark_re)
      puts "<#{type}>"
      push_indent(indentof(@f.peek)) {
        @f.while_match(mark_re) do |line|
          line = emulate_rdstyle(line) if /\A\s*[\*\#]{2,}/ =~ line
          if indent_shallower?(line)
            @f.ungets line
            break
          end
          if indent_deeper?(line)
            @f.ungets line
            xlist type, mark_re
          else
            puts "<li>#{text(line.sub(mark_re, '').strip)}</li>"
          end
          @f.skip_blank_lines
        end
      }
      puts "</#{type}>"
    end

    def emulate_rdstyle(line)
      marks = line.slice(/\A\s*[\*\#]+/).strip
      line.sub(/\A\s*[\*\#]+\s*/) {
        if marks.size <= (@indent_stack.size - 1)
          ' ' * @indent_stack[marks.size] + marks[0,1]
        else
          ' ' * (current_indent() + 1) + marks[0,1]
        end
      }
    end

    def dl
      puts '<dl>'
      @f.while_match(DL) do |line|
        _, dt, dd = line.strip.split(/\s*:\s*/, 3)
        puts "<dt>#{text(dt)}</dt><dd>#{text(dd.to_s)}</dd>"
      end
      puts '</dl>'
    end

    def cite
      puts '<blockquote>'
      @f.while_match(CITE) do |line|
        puts line.sub(/\A""/).strip
      end
      puts '</blockquote>'
    end

    def table
      buf = []
      @f.while_match(TABLE) do |line|
        cols = line.strip.split(/(\|\|\|?)/)
        cols.shift   # discard first ""
        cols.pop if (cols.last == '||') or (cols.size % 2 == 1)
        tmp = []
        until cols.empty?
          th = (cols.shift == '|||')
          tmp.push [cols.shift, th]
        end
        buf.push tmp
      end
      n_maxcols = buf.map {|cols| cols.size }.max
      puts '<table>'
      buf.each do |cols|
        cols.concat [['',false]] * (n_maxcols - cols.size)
        puts '<tr>' +
             cols.map {|col, th|
               if th
               then "<th>#{text(col.strip)}</th>"
               else "<td>#{text(col.strip)}</td>"
               end
             }.join('') +
             '</tr>'
      end
      puts '</table>'
    end

    def pre
      @f.gets   # discard '{{{'
      puts '<pre>'
      @f.until_terminator(/\A\}\}\}/) do |line|
        puts escape_html(line.rstrip)
      end
      puts '</pre>'
    end

    #
    # Indent
    #

    def push_indent(n)
      raise "shollower indent pushed: #{@indent_stack.inspect}" \
          unless n >= current_indent()
      @indent_stack.push n
      yield
    ensure
      @indent_stack.pop
    end

    def current_indent
      @indent_stack.last
    end

    def indent_deeper?(line)
      indentof(line) > current_indent()
    end

    def indent_shallower?(line)
      indentof(line) < current_indent()
    end

    def indentof(line)
      detab(line.slice(/\A\s*/)).length
    end

    #
    # Inline
    #

    WikiName = /\b(?:[A-Z][a-z0-9]+){2,}\b/n   # /\b/ requires `n' option
    BlacketLink = /\[\[\S+?\]\]/e
        # FIXME: `e' option does not effect in the final regexp.
    schemes = %w( http ftp )
    SeemsURL = /\b(?=#{Regexp.union(*schemes)}:)#{URI::PATTERN::X_ABS_URI}/xn
        # from uri/common.rb:URI.extract
    NeedESC = /[&"<>]/

    def text(str)
      esctable = TextUtils::ESC
      str.gsub(/(#{NeedESC})|(#{WikiName})|(#{BlacketLink})|(#{SeemsURL})/on) {
        if    ch  = $1 then esctable[ch]
        elsif tok = $2 then internal_link(tok)
        elsif tok = $3
          case link = tok[2..-3]
          when SeemsURL      then %[<a href="#{escape_html(link)}">#{escape_html(link)}</a>]
          when /\A[\w\-]+:/n then interwiki(*link.split(/:/, 2))
          when /\A\w+\z/n    then internal_link(link)
          else                    tok
          end
        elsif tok = $4 then seems_url(tok)
        else
          raise 'must not happen'
        end
      }
    end

    def internal_link(name)
      return escape_html(name) if name == @page_name
      return escape_html(name) if @repository.invalid?(name)
      @internal_links.push name
      if @repository.exist?(name)
      then %Q[<a href="#{view_url(name)}">#{escape_html(name)}</a>]
      else %Q[<a href="#{view_url(name)}">?</a>#{escape_html(name)}]
      end
    end

    def view_url(name)
      if @config.html_url?
      then "#{escape_html(URI.escape(name))}.html"
      else "#{cgi_href()}?cmd=view;name=#{escape_html(URI.escape(name))}"
      end
    end

    def cgi_href
      escape_html(@config.cgi_url)
    end

    def interwiki(id, vary)
      href = resolve_interwikiname(id, vary)
      anchor = escape_html("[#{id}:#{vary}]")
      if href
      then %Q[<a href="#{escape_html(URI.escape(href))}">#{anchor}</a>]
      else '?' + anchor
      end
    end

    def resolve_interwikiname(name, vary)
      table = interwikiname_table() or return nil
      return nil unless table.key?(name)
      sprintf(table[name], vary)
    end

    def interwikiname_table
      @interwikinames ||= read_interwikiname_table()
    end

    InterWikiName_LIST_PAGE = 'InterWikiName'

    def read_interwikiname_table()
      text = @repository[InterWikiName_LIST_PAGE] or return {}
      table = {}
      text.each do |line|
        if /\A\s*\*\s*(\S+?):/ =~ line
          interwikiname = $1
          url = $'.strip
          table[interwikiname.strip] = url.strip
        end
      end
      table
    end

    def seems_url(url)
      if url[-1,1] == ')' and not paren_balanced?(url)   # special case
        url[-1,1] = ''
        add = ')'
      else
        add = ''
      end
      if seems_image_url?(url)
      then %Q[<img src="#{escape_html(url)}">#{add}]
      else %Q[<a href="#{escape_html(url)}">#{escape_html(url)}</a>#{add}]
      end
    end

    def seems_image_url?(url)
      /\.(?:png|jpg|jpeg|gif|bmp|tiff|tif)\z/i =~ url
    end

    def paren_balanced?(str)
      str.count('(') == str.count(')')
    end

    #
    # I/O
    #

    def print(str)
      @result << str
    end

    def puts(str)
      @result << str
      @result << "\n" unless /\n\z/ =~ str
    end

    class LineInput
      def initialize(f)
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

      def ungets(line)
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

      def while_match(re)
        while line = gets()
          unless re =~ line
            ungets line
            return
          end
          yield line
        end
        nil
      end

      def until_match(re)
        while line = gets()
          if re =~ line
            ungets line
            return
          end
          yield line
        end
        nil
      end

      def until_terminator(re)
        while line = gets()
          return if re =~ line   # discard terminal line
          yield line
        end
        nil
      end
    end

  end

end   # module BitChannel
