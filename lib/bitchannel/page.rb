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

    def last_modified
      @repository.mtime(@page_name)
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

    def page_list
      @repository.entries.sort.map {|name| escape_html(name) }
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

    def page_list
      @repository.entries\
          .map {|name| [escape_html(name), @repository.mtime(name)] }\
          .sort_by {|name, mtime| -(mtime.to_i) }
    end

  end


  class HistoryPage < Page

    private

    def template_id
      'history'
    end

    def logs
      @repository.getlog(@page_name)
    end
  
  end

end
