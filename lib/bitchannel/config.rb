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
        @locale      = conf.get_required(:locale)
        @templatedir = conf.get_required(:templatedir)
        @css_url     = conf.get_optional(:css_url, nil)
        @theme       = conf.get_optional(:theme, nil)
        @theme_url   = conf.get_optional(:theme_url, 'theme')
        @html_url_p  = conf.get_required(:use_html_url)
        @site_name   = conf.get_optional(:site_name, nil)
        @logo_url    = conf.get_optional(:logo_url, nil)
        @cgi_url     = conf.get_optional(:cgi_url, nil)
      }
      if @theme and @css_url
        raise ConfigError, "both of theme and css_url given"
      end
      if not @theme and not @css_url
        raise ConfigError, "theme or css_url required"
      end
    end

    attr_reader :templatedir
    attr_reader :logo_url

    def css_url
      @css_url || "#{@theme_url}/#{@theme}/#{@theme}.css"
    end

    def charset
      @locale.charset
    end

    def text(key)
      @locale.text(key)
    end

    def html_url?
      @html_url_p
    end

    def suggest_cgi_url(url)
      @cgi_url ||= url
      @cgi_url
    end

    def cgi_url
      return @cgi_url if @cgi_url
      return ENV['SCRIPT_NAME'] if ENV['SCRIPT_NAME']
      return File.basename(::Apache.request.filename) if defined?(::Apache)
      return File.basename($0) if $0
      raise "cannot get cgi url; given up"
    end

    def site_name
      @site_name || FRONT_PAGE_NAME
    end
  end

end
