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

  class UserConfig
    def UserConfig.parse(hash, cat)
      conf = new(hash, cat)
      yield conf
      conf.check_unknown_options
    end
      
    def initialize(hash, cat)
      @config = hash.dup
      @category = cat
    end

    def get_required(key)
      raise ConfigError, "Config Error: not set: #{@category}.#{key}" \
          unless @config.key?(key)
      @config.delete(key).untaint
    end

    def get_optional(key, default)
      return default unless @config.key?(key)
      @config.delete(key).untaint
    end

    def check_unknown_options
      @config.each do |key, val|
        raise ConfigError, "Config Error: unknown key: #{@category}.#{key}"
      end
    end
  end


  FRONT_PAGE_NAME = 'FrontPage'
  HELP_PAGE_NAME = 'HelpPage'
  TMP_PAGE_NAME = 'tmp'

  class Config
    def initialize(hash)
      UserConfig.parse(hash, 'config') {|conf|
        @locale        = conf.get_required(:locale)
        @templatedir   = conf.get_required(:templatedir)
        @css_url       = conf.get_optional(:css_url, nil)
        @theme         = conf.get_optional(:theme, nil)
        @theme_urlbase = conf.get_optional(:theme_urlbase, 'theme')
        fakeurl = conf.get_required(:use_html_url)
        @html_url_p = (fakeurl ? true : false)
        @suffix = case
                  when fakeurl.kind_of?(String) then fakeurl
                  when fakeurl                  then '.html'
                  else nil
                  end
        @site_name     = conf.get_optional(:site_name, nil)
        @logo_url      = conf.get_optional(:logo_url, nil)
        @user_cgi_url  = conf.get_optional(:cgi_url, nil)
        @guess_cgi_url = nil
      }
      if @theme and @css_url
        raise ConfigError, "both of theme and css_url given"
      end
      if not @theme and not @css_url
        raise ConfigError, "theme or css_url required"
      end
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
