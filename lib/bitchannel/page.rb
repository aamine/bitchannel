#
# $Id$
#
# Copyright (C) 2003 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.
#

require 'alphawiki/repository'
require 'alphawiki/tohtml'
require 'alphawiki/textutils'
require 'erb'

module AlphaWiki

  class Page

    include TextUtils

    def initialize(config, page)
      @config = config
      @page_name = page
      @repository = Repository.new(config.datadir)
    end

    def html
      ERB.new(@config.read_rhtml(template_id())).result(binding())
    end

    private

    def title
      page_name()
    end

    def page_name
      escape_html(@page_name)
    end

    def css_url
      @config.css_url
    end

    def cgi_url
      @config.cgi_url
    end

  end


  class ViewPage < Page

    private

    def template_id
      'view'
    end

    def body
      ToHTML.compile(@repository[@page_name])
    end

    def opt_headers
      ''
    end
  
  end


  class EditPage

    private

    def template_id
      'edit'
    end

    def body
      escape_html(@repository[@page_name])
    end

    def page_revision
      0   # FIXME
    end

    def opt_headers
      ''
    end

  end


  class SavePage

    private

    def template_id
      'save'
    end

    def body
      escape_html(@repository[@page_name])
    end

    def opt_headers
      ''
    end

  end

end
