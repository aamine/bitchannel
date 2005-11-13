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
    end

    def extract_links(str)
      []
    end

    def compile(str, page_name)
      if /\A\#@@@meta/ =~ str
      then meta(str, page_name)
      else compile(str)
      end
    end

    private

    def meta(str, page_name)
      @repository.instance_eval { @wc_read }.chdir {
        return Object.new.instance_eval(str, "(meta:#{page_name})")
      }
    end

    def compile(str)
      src = str.to_a   # optimize
      s = ReVIEW::HTMLBuilder.new(
        ReVIEW::LocalizeMark.new(@config.locale,
            ReVIEW::ChapterIndex.load(@repository[::ReVIEW.CHAPS].source)\
                {|fname| @repository[fname].source }),
        ReVIEW::LocalizeMark.new(@config.locale, ReVIEW::ListIndex.parse(src)),
        ReVIEW::LocalizeMark.new(@config.locale, ReVIEW::ImageIndex.parse(src)),
        ReVIEW::LocalizeMark.new(@config.locale, ReVIEW::TableIndex.parse(src))
      )
      ::ReVIEW::Compiler.new(s).compile(str)
    end
  
  end

end   # module BitChannel
