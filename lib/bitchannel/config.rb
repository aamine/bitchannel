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
      @index_page  = t.fetch(:index_page, nil); t.delete(:index_page)
      @help_page   = t.fetch(:help_page, nil);  t.delete(:help_page)
      @site_name   = t.fetch(:site_name, nil);  t.delete(:site_name)

      t.each do |k,v|
        raise ConfigError, "Config Error: unknown key: config.#{k}"
      end
    end

    attr_reader :templatedir
    attr_reader :charset
    attr_reader :css_url

    def html_url?
      @html_url_p
    end

    def cgi_url
      File.basename($0)
    end

    def site_name
      @site_name || index_page_name()
    end

    def index_page_name
      @index_page || 'FrontPage'
    end

    def help_page_name
      @help_page || 'HelpPage'
    end

    def tmp_page_name
      'tmp'
    end

  end

end
