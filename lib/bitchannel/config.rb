#
# $Id$
#
# Copyright (C) 2003 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.
#

module BitChannel

  class Config

    def initialize(args)
      t = Hash.new {|h,k|
        raise ConfigError, "Config Error: not set: config.#{k}"
      }
      t.update args
      @templatedir = t[:templatedir]; t.delete(:templatedir)
      @cachedir    = t[:cachedir];    t.delete(:cachedir)
      @charset     = t[:charset];     t.delete(:charset)
      @cgi_url     = t[:cgi_url];     t.delete(:cgi_url)
      @css_url     = t[:css_url];     t.delete(:css_url)
      @index_page = t.fetch(:index_page, nil); t.delete(:index_page)
      @site_name = t.fetch(:site_name, nil); t.delete(:site_name)
      t.each do |k,v|
        raise ConfigError, "Config Error: unknown key: config.#{k}"
      end
    end

    attr_reader :charset
    attr_reader :cgi_url
    attr_reader :css_url
    attr_reader :datadir
    attr_reader :templatedir

    def site_name
      @site_name || index_page_name()
    end

    def index_page_name
      @index_page || 'FrontPage'
    end

    def help_page_name
      'HelpPage'
    end

    def tmp_page_name
      'SandBox'
    end

    def link_cachedir
      "#{@cachedir}/link"
    end

    def revlink_cachedir
      "#{@cachedir}/revlink"
    end

  end

end
