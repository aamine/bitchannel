#
# $Id$
#
# Copyright (C) 2003 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.
#

require 'alphawiki/tohtml'
require 'alphawiki/textutils'
require 'erb'

module AlphaWiki

  class View

    include TextUtils

    def initialize(config, page)
      @config = config
      @pagename = page
    end

    TEMPLATE = 'view.rhtml'

    def html
      ERB.new(@config.read_rhtml(TEMPLATE)).result(binding())
    end

    private

    def title
      beautify_wikiname(@pagename)
    end

    def body
      ToHTML.compile(@config.read_pagesrc(@pagename))
    end

    def css_url
      @config.css_url
    end

    def opt_headers
      ''
    end
  
  end


  class Edit

    include TextUtils

    def initialize(config, name)
      @config = config
      @pagename = name
    end

    TEMPLATE = 'edit.rhtml'

    def html
      ERB.new(@config.read_rhtml(TEMPLATE)).result(binding())
    end

    private

    def title
      beautify_wikiname(@pagename)
    end

    def body
      escape_html(@config.read_pagesrc(@pagename))
    end

    def cgi_url
      @config.cgi_url
    end

    def css_url
      @config.css_url
    end

    def opt_headers
      ''
    end

  end

end
