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

    def initialize(config, repo, page)
      @config = config
      @repository = repo
      @page_name = page
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

    def initialize(config, repo, page_name, rev = nil, text = nil, msg = nil)
      super config, repo, page_name
      @rev = rev
      @text = text
      @message = msg
    end

    private

    def template_id
      'edit'
    end
    
    def message
      return '' unless @message
      '<p>' + escape_html(@message) + '</p>'
    end

    def body
      return @text if @text
      escape_html(@repository[@page_name])
    end

    def page_revision
      @rev || 0
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
