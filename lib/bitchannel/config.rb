#
# $Id$
#
# Copyright (C) 2003-2006 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'bitchannel/userconfig'

module BitChannel

  FRONT_PAGE_NAME = 'FrontPage'
  HELP_PAGE_NAME = 'HelpPage'
  TMP_PAGE_NAME = 'tmp'

  DEFAULT_KILL_FILE = 'kill'

  class Config

    def initialize(hash)
      UserConfig.parse(hash, 'config') {|conf|
        @locale        = conf.get_required(:locale)
        @templatedir   = conf.get_required(:templatedir)
        conf.select! :theme, :css_url
        @css_url       = conf[:css_url]
        @theme         = conf[:theme]
        @theme_urlbase = conf[:theme_urlbase] || 'theme'
        fakeurl = conf.get_required(:use_html_url)
        @html_url_p = (fakeurl ? true : false)
        @suffix = case
                  when fakeurl.kind_of?(String) then fakeurl
                  when fakeurl                  then '.html'
                  else nil
                  end
        @site_name     = conf[:site_name]
        @logo_url      = conf[:logo_url]
        @user_cgi_url  = conf[:cgi_url]
        @guess_cgi_url = nil
      }
    end

    attr_reader :locale
    attr_reader :templatedir
    attr_reader :site_name
    attr_reader :logo_url

    def css_url
      @css_url || "#{@theme_urlbase}/#{@theme}/#{@theme}.css"
    end

    def html_url?
      @html_url_p
    end

    def document_suffix
      @suffix
    end

    def cgi_url
      @user_cgi_url || @guess_cgi_url
    end

    def cgi_url=(u)
      @guess_cgi_url = u
    end

  end

end
