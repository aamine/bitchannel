#
# $Id$
#
# Copyright (c) 2003-2006 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'bitchannel/lineinput'
require 'bitchannel/textutils'
require 'bitchannel/page'
require 'bitchannel/locale'
require 'stringio'

module BitChannel

  loc = Locale.get('ja_JP.eucJP')
  loc[:parens] = "\241\312%s\241\313"
  loc[:chapter_number_format] = "\302\350%d\276\317"
  loc[:chapter_caption_format] = "\241\326%s\241\327"
  loc[:list_number_format] = "\245\352\245\271\245\310%d"
  loc[:list_caption_format] = '%s'
  loc[:image_number_format] = "\277\336%d"
  loc[:image_caption_format] = '%s'
  loc[:table_number_format] = "\311\275%d"
  loc[:table_caption_format] = '%s'

  # reopen
  class ViewPage
    alias org_last_modified last_modified
    remove_method :last_modified

    def last_modified
      if page_name() == 'FrontPage'
      then Time.now
      else org_last_modified()
      end
    end

    undef page_title
    def page_title
      caption = @page.source.slice(/\A=(.*)/, 1)
      if caption
      then caption.strip
      else page_name()
      end
    end
  end

  class ERDSyntax

    include TextUtils

    def initialize(config, repo)
      @config = config
      @repository = repo
    end

    def extract_links(str)
      []
    end

    def compile(str, page_name)
      if /\A\#@@@meta/ =~ str
      then meta(str, page_name)
      else compile_erd(str)
      end
    end

    private

    def meta(str, page_name)
      @repository.instance_eval { @wc_read }.chdir {
        return Object.new.instance_eval(str, "(meta:#{page_name})")
      }
    end

    def compile_erd(str)
      ::ERD::Compiler.new(@repository, @config.locale).compile(str)
    end
  
  end

end   # module BitChannel


module ERD

  class Compiler

    include ::BitChannel::TextUtils

    def initialize(repo, locale, indexes = {})
      @repository = repo
      @locale = locale
      @indexes = indexes
    end

    def compile(str)
      @f = LineInput.new(StripAuthorTags.new(StringIO.new(str)))
      @output = StringIO.new
      @warns = []
      @errors = []
      src = str.to_a   # optimize
      @indexes[:chapter] ||= ChapterIndex.parse(@repository['CHAPS'].source, @repository.instance_eval { @wc_read }.instance_eval { @fs })
      @indexes[:list]    ||= ListIndex.parse(src, @errors)
      @indexes[:image]   ||= ImageIndex.parse(src, @errors)
      @indexes[:table]   ||= TableIndex.parse(src, @errors)
      @chapter_index = FormatRef.new(@locale, @indexes[:chapter])
      @list_index    = FormatRef.new(@locale, @indexes[:list])
      @image_index   = FormatRef.new(@locale, @indexes[:image])
      @table_index   = FormatRef.new(@locale, @indexes[:table])
      _compile
      msg = messages()
      if msg.empty?
      then @output.string
      else msg + @output.string
      end
    end

    private

    def _compile
      while line = @f.gets
        case line
        when /\A(=+)/       then caption line
        when %r<\A//read>   then lead
        when %r<\A//emlist> then quotedlist 'emlist'
        when %r<\A//cmd>    then quotedlist 'cmd'
        when %r<\A//list>   then list(*parse_option(line, 2))
        when %r<\A//image>  then image(*parse_option(line, 2))
        when %r<\A//table>  then table(*parse_option(line, 2))
        when %r<\A//prototype> then quotedlist 'prototype'
        when %r<\A\s+\*>
          @f.ungets line
          ul
        when %r<\A\s+\d+\.>
          @f.ungets line
          ol
        when %r<\A:>
          @f.ungets line
          dl
        when %r<\A//comment>
          ;
        when %r[\A//\}]
          error 'block close mismatch'
        when %r[\A//]
          error "wrong command line: #{line.strip}"
        else
          next if line.strip.empty?
          @f.ungets line
          paragraph
        end
      end
    end

    def caption(line)
      level = line.slice(/\A=+/).size
      return if level == 1
      cap = line.sub(/\A=+/, '').strip
      puts '' if level > 1
      puts "<h#{level}>#{escape_html(cap)}</h#{level}>"
    end

    def lead
      puts '<p class="lead">'
      each_block_line do |line|
        puts text(line.strip)
      end
      puts '</p>'
    end

    def quotedlist(css_class)
      puts %Q[<blockquote><pre class="#{css_class}">]
      each_block_line do |line|
        puts escape_html(detab(line))
      end
      puts '</pre></blockquote>'
    end

    def list(id, caption)
      begin
        puts %Q[<p class="toplabel">#{@list_index.number(id)}: #{escape_html(caption)}</p>]
      rescue KeyError => err
        error "no such list: #{id}"
      end
      puts '<pre class="list">'
      each_block_line do |line|
        puts escape_html(detab(line))
      end
      puts '</pre>'
    end

    def image(id, caption)
      if @image_index.file_exist?(id)
        puts %Q[<p class="image">]
        puts %Q[<img src="#{@image_index.file(id)}" alt="(#{escape_html(caption)})"><br>]
        puts %Q[#{@image_index.number(id)}: #{escape_html(caption)}]
        puts %Q[</p>]
      else
        puts %Q[<pre class="dummyimage">]
        each_block_line do |line|
          puts escape_html(detab(line))
        end
        puts %Q[</pre>]
        puts %Q[<p class="botlabel">]
        puts %Q[#{@image_index.number(id)}: #{escape_html(caption)}]
        puts %Q[</p>]
      end
    end

    def table(id, caption)
      sep_seen = false
      rows = []
      each_block_line do |line|
        if /\A[\=\-]{12}/ =~ line
          sep_seen = true
          next
        end
        rows.push line.strip.split(/\t+/).map {|s| s.sub(/\A\./, '') }
      end
      rows = adjust_n_cols(rows)

      puts %Q[<p class="toplabel">#{@table_index.number(id)}: #{escape_html(caption)}</p>]
      puts '<table>'
      if sep_seen
        puts '<tr>' +
             rows.shift.map {|s| "<th>#{text(s)}</th>" }.join('') +
             '</tr>'
        rows.each do |cols|
          puts '<tr>' +
               cols.map {|s| "<td>#{text(s)}</td>" }.join('') +
               '</tr>'
        end
      else
        rows.each do |cols|
          h, *cs = *cols
          puts "<tr><th>#{text(h)}</th>" +
               cs.map {|s| "<td>#{text(s)}</td>" }.join('') +
               '</tr>'
        end
      end
      puts '</table>'
    end

    def adjust_n_cols(rows)
      rows.each do |cols|
        while cols.last and cols.last.strip.empty?
          cols.pop
        end
      end
      n_maxcols = rows.map {|cols| cols.size }.max
      rows.each do |cols|
        cols.concat [''] * (n_maxcols - cols.size)
      end
      rows
    end

    def each_block_line
      @f.until_terminator(%r<\A//\}>) do |line|
        yield line.rstrip
      end
    end

    def parse_option(header, argc)
      opts = header.scan(/\[.*?\]/).map {|s| s[1..-2] }
      unless opts.size == argc
        error "wrong number of arguments (#{opts.size} for #{argc})"
        return ['(ERROR)'] * argc
      end
      opts
    end

    def ul
      puts '<ul>'
      @f.while_match(/\A\s+\*/) do |line|
        buf = line.sub(/\*/, '').strip
        @f.while_match(/\A\s+(?!\*)\S/) do |line|
          buf << line.strip
        end
        puts "<li>#{text(buf)}</li>"
      end
      puts '</ul>'
    end

    def ol
      puts '<ol>'
      @f.while_match(/\A\s+\d+\./) do |line|
        buf = line.sub(/\d+\./, '').strip
        @f.while_match(/\A\s+(?!\d+\.)\S/) do |line|
          buf << line.strip
        end
        puts "<li>#{text(buf)}</li>"
      end
      puts '</ol>'
    end

    def dl
      puts '<dl>'
      while /\A:/ =~ @f.peek
        puts "<dt>#{escape_html(@f.gets.sub(/:/, '').strip)}</dt>"
        print '<dd>'
        @f.until_match(/\A\S/) do |line|
          puts escape_html(line.strip)
        end
        puts '</dd>'
        @f.skip_blank_lines
      end
      puts '</dl>'
    end

    def paragraph
      print '<p>'
      nl = ''
      @f.until_match(%r<\A//>) do |line|
        break if line.strip.empty?
        print nl; print text(line.strip)
        nl = "\n"
      end
      puts '</p>'
    end

    def text(str)
      str.gsub(/@<(\w+)>\{(.*?)\}/) {
        begin
          op = $1
          arg = $2
          case op
          when 'chap'  then @chapter_index.number(arg)
          when 'title' then @chapter_index.caption(arg)
          when 'list'  then @list_index.number(arg)
          when 'img'   then @image_index.number(arg)
          when 'table' then @table_index.number(arg)
          when 'bou'   then escape_html(arg)
          when 'ruby'
            base, ruby = *arg.split(',', 2)
            escape_html(base)
          when 'kw'
            word, alt = *arg.split(',', 2)
            '<span class="kw">' +
              if alt
              then escape_html(word + sprintf(@locale[:parens], alt.strip))
              else escape_html(word)
              end +
            '</span>'
          else
            error "unknown inline command: @<#{op}>"
            "@<#{op}>{#{escape_html(arg)}}"
          end
        rescue => err
          error err.message
          "@<#{op}>{#{escape_html(arg)}}"
        end
      }
    end

    def warn(msg)
      @warns.push [@f.lineno, msg]
      puts "----WARNING: #{escape_html(msg)}----"
    end

    def error(msg)
      @errors.push [@f.lineno, msg]
      puts "----ERROR: #{escape_html(msg)}----"
    end

    def messages
      error_messages() + warning_messages()
    end

    def error_messages
      return '' if @errors.empty?
      "<h2>Syntax Errors</h2>\n" +
      "<ul>\n" +
      @errors.map {|n, msg| "<li>#{n}: #{escape_html(msg.to_s)}</li>\n" }.join('') +
      "</ul>\n"
    end

    def warning_messages
      return '' if @warns.empty?
      "<h2>Warnings</h2>\n" +
      "<ul>\n" +
      @warns.map {|n, msg| "<li>#{n}: #{escape_html(msg)}</li>\n" }.join('') +
      "</ul>\n"
    end

    def print(s)
      @output.print s
    end

    def puts(s)
      @output.puts s
    end

  end

  class StripAuthorTags
    def initialize(f)
      @f = f
    end

    def gets
      while line = @f.gets
        next if /\A\#@/ =~ line
        next if /\A\####/ =~ line
        return line
      end
      nil
    end
  end


  class Index
    def Index.parse(src, errbuf = nil)
      a = []
      seq = 1
      src.grep(%r<^//#{item_type()}>).each do |line|
        opts = line.scan(/\[.*?\]/).map {|s| s[1..-2] }
        unless opts.size == 2
          raise ArgumentError, "wrong //#{item_type} header" unless errbuf
          errbuf.push "wrong //#{item_type} header"
          next
        end
        id, caption = *opts
        a.push Item.new(id, seq, caption)
        seq += 1
      end
      new(a)
    end

    def item_type
      self.class.item_type
    end

    def initialize(items)
      @items = items
      @index = {}
      items.each do |i|
        @index[i.id] = i
      end
    end

    def number(id)
      @index.fetch(id).number
    end

    def caption(id)
      @index.fetch(id).caption
    end
  end

  class ChapterIndex < Index
    def ChapterIndex.load(path)
      parse(File.read(path))
    end

    def ChapterIndex.parse(str, fs = ::File)
      a = []
      str.split.each_with_index do |file, idx|
        a.push Item.new(file.sub(/\.e?rd/, ''), idx + 1, read_title(file, fs))
      end
      new(a)
    end

    def ChapterIndex.read_title(path, fs)
      fs.open(path) {|f|
        return f.gets.sub(/\A=/, '').strip
      }
    end

    def item_type
      'chapter'
    end

    def display_string(id)
      number(id) + caption(id)
    end
  end

  class ListIndex < Index
    def ListIndex.item_type
      'list'
    end
  end

  class ImageIndex < Index
    def ImageIndex.item_type
      'image'
    end

    def file_exist?(id)
      false   # FIXME: tmp
    end

    def file(id)
      "images/#{id}.jpg"   # FIXME: tmp
    end
  end

  class TableIndex < Index
    def TableIndex.item_type
      'table'
    end
  end

  Item = Struct.new(:id, :number, :caption)


  class FormatRef
    def initialize(locale, index)
      @locale = locale
      @index = index
    end

    def caption(id)
      sprintf(@locale["#{@index.item_type}_caption_format".intern],
              @index.caption(id))
    end

    def number(id)
      sprintf(@locale["#{@index.item_type}_number_format".intern],
              @index.number(id))
    end

    def method_missing(mid, *args, &block)
      super unless @index.respond_to?(mid)
      @index.__send__(mid, *args, &block)
    end
  end

end   # module ERD
