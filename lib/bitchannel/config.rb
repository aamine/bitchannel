#
# $Id$
#
# Copyright (C) 2003 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.
#

module Wikitik

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
      t.each do |k,v|
        raise ConfigError, "Config Error: unknown key: config.#{k}"
      end
      @index_page = nil
    end

    attr_reader :charset
    attr_reader :cgi_url
    attr_reader :css_url
    attr_reader :datadir

    INDEX_PAGE = 'IndexPage'

    def index_page_name
      @index_page || INDEX_PAGE
    end

    def tmp_page_name
      'SandBox'
    end

    def read_rhtml(name)
      File.read("#{@templatedir}/#{name}.rhtml")
    end

    def link_cachedir
      "#{@cachedir}/link"
    end

    def revlink_cachedir
      "#{@cachedir}/revlink"
    end

  end

end
