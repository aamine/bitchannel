#
# $Id$
#
# Copyright (C) 2003 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.
#

module AlphaWiki

  class Config

    def initialize(config_env)
      @charset, @cgi_url, @css_url, @templatedir =
          *config_env.instance_eval {
            [@charset, @cgi_url, @css_url, @templatedir]
          }
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

  end

end
