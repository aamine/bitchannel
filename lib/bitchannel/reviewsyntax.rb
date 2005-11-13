#
# $Id$
#
# Copyright (c) 2003-2005 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'bitchannel/page'
require 'bitchannel/locale'
require 'review'

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

  class ReVIEWSyntax

    include TextUtils

    def initialize(config, repo)
      @config = config
      @repository = repo
      @env = ReVIEW::Environment.load(repo.instance_variable_get(:@wc_read).dir + '/PARAMS')
    end

    def extract_links(str)
      []
    end

    def compile(str, page_name)
      case
      when File.extname(page_name) == '.re'
        review_compile(str, page_name)
      when /\A\#@@@meta/ =~ str
        meta(str, page_name)
      else
        "<pre>#{escape_html(str)}</pre>"
      end
    end

    private

    def meta(str, page_name)
      @repository.instance_eval { @wc_read }.chdir {
        return Object.new.instance_eval(str, "(meta:#{page_name})")
      }
    end

    def review_compile(str, page_name)
      src = str.to_a   # optimize
      strategy = ReVIEW::HTMLBuilder.new([
        new_index(src) {|s| @env.chapter_index },
        new_index(src) {|s| ReVIEW::ListIndex.parse(s) },
        new_index(src) {|s| ReVIEW::ImageIndex.parse(s) },
        new_index(src) {|s| ReVIEW::TableIndex.parse(s) }
      ])
      ReVIEW::Compiler.new(strategy).compile(str, page_name)
    end

    def new_index(src)
      ReVIEW::FormatRef.new(@config.locale, yield(src))
    rescue
      ReVIEW::FormatRef.new(@config.locale, yield(''))
    end
  
  end

end   # module BitChannel
