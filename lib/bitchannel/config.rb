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

    def UserConfig.parse(hash, category)
      conf = new(hash, category)
      yield conf
      conf.check_unknown_options
    end
      
    def initialize(hash, category)
      @config = hash.dup
      @config.each_value do |v|
        v.untaint
      end
      @category = category
      @refered = []
    end

    def get(key)
      @refered.push key
      return nil unless @config.key?(key)
      if block_given?
      then yield(@config[key])
      else @config[key]
      end
    end

    alias [] get

    def get_required(key)
      required! key
      get(key)
    end

    def ignore(key)
      @refered.push key
    end

    # Just 1 key must exist
    def required!(key)
      unless @config.key?(key)
        raise ConfigError, "Config Error: not set: #{@category}.#{key}"
      end
    end

    # Only 0 or 1 key from KEYS must exist
    def exclusive!(*keys)
      if keys.map {|k| @config.key?(k) }.select {|b| b }.size > 1
        raise ConfigError,
            keys.map {|k| "#{@category}.#{k}" }.join(' and ') + ' are exclusive'
      end
    end

    # Only 1 key from KEYS must exist
    def select!(*keys)
      exclusive! keys
      if keys.all? {|k| not @config.key?(k) }
        raise ConfigError,
            "at least 1 key required: " +
            keys.map {|k| "#{@category}.#{k}" }.join(', ')
      end
    end

    def check_unknown_options
      unknown = (@config.keys - @refered).uniq
      unless unknown.empty?
        raise ConfigError,
            'BitChannel Configuration Error: unknown keys: ' +
            unknown.map {|k| "#{@category}.#{k}" }.join(', ')
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
