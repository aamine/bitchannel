#
# $Id$
#
# Copyright (C) 2003 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

module BitChannel

  FRONT_PAGE_NAME = 'FrontPage'
  HELP_PAGE_NAME = 'HelpPage'
  TMP_PAGE_NAME = 'tmp'

  class Config
    def initialize(args)
      t = Hash.new {|h,k|
        raise ConfigError, "Config Error: not set: config.#{k}"
      }
      t.update args

      # Required
      @templatedir = t[:templatedir];  t.delete(:templatedir)
      @charset     = t[:charset];      t.delete(:charset)
      @css_url     = t[:css_url];      t.delete(:css_url)
      @html_url_p  = t[:use_html_url]; t.delete(:use_html_url)

      # Optional
      @site_name   = t.fetch(:site_name, nil);  t.delete(:site_name)
      @logo_url    = t.fetch(:logo_url, nil);   t.delete(:logo_url)

      t.each do |k,v|
        raise ConfigError, "Config Error: unknown key: config.#{k}"
      end
    end

    attr_reader :templatedir
    attr_reader :charset
    attr_reader :css_url
    attr_reader :logo_url

    def html_url?
      @html_url_p
    end

    def cgi_url
      File.basename($0)
    end

    def site_name
      @site_name || FRONT_PAGE_NAME
    end
  end

end
