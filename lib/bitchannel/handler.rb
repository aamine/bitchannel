#
# $Id$
#
# Copyright (C) 2003 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.
#

require 'erb'

module AlphaWiki

  class View

    def initialize( config, page )
      @config = config
      @pagename = page
      @body = nil
    end

    TEMPLATE = 'view.rhtml'

    def tohtml
      @body = ToHTML.compile(@config.read_page(page))
      ERB.new(rhtml()).result(self)
    end

    def title
      @pagename
    end

    def body
      @body
    end

    def css_url
      @config.css_url
    end

    def additinal_headers
      ''
    end
  
  end

end
