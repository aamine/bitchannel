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
require 'forwardable'

module AlphaWiki

  class Page

    include TextUtils
    extend Forwardable

    def initialize(config, repo, page)
      @config = config
      @repository = repo
      @page_name = page
    end

    def html
      ERB.new(@config.read_rhtml(template_id())).result(binding())
    end

    private

    def_delegator :@config, :charset
    def_delegator :@config, :css_url
    def_delegator :@config, :cgi_url

    def title
      page_name()
    end

    def page_name
      escape_html(@page_name)
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
  
  end


  class EditPage < Page

    def initialize(config, repo, page_name, rev = nil, text = nil, msg = nil)
      super config, repo, page_name
      @rev = rev || @repository.revision(@page_name)
      @text = text
      @opt_message = msg
    end

    private

    def template_id
      'edit'
    end
    
    def opt_message
      return '' unless @opt_message
      "<p>#{escape_html(@opt_message)}</p>"
    end

    def body
      return @text if @text
      begin
        return escape_html(@repository[@page_name])
      rescue Errno::ENOENT
        return ''
      end
    end

    def page_revision
      @rev || 0
    end

  end


  class ListPage < Page

    def initialize(config, repo)
      super config, repo, 'List'
    end

    private

    def template_id
      'list'
    end

    def body
      "<ul>" +
      @repository.entries.sort.map {|ent|
        "<li>#{#{escape_html(ent)}</li>"
      }.join("\n") +
      "</ul>"
    end

  end


  class RecentPage < Page

    def initialize(config, repo)
      super config, repo, 'Recent'
    end

    private

    def template_id
      'recent'
    end

    def body
      "<ul>" +
      @repository.entries.map {|ent| [ent, @repository.mtime(ent)] }\
      .sort_by {|ent, mtime| mtime }.map {|ent, mtime|
        "<li>#{format_time(mtime)}: #{#{escape_html(ent)}</li>"
      }.join("\n") +
      "\n</ul>"
    end

  end

end
