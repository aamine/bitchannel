#
# $Id$
#
# Copyright (C) 2003 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.
#

require 'wikitik/repository'
require 'wikitik/tohtml'
require 'wikitik/textutils'
require 'erb'
require 'forwardable'

module Wikitik

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

    def initialize(*args)
      super
      @rev = nil
    end

    def last_modified
      @repository.mtime(@page_name)
    end

    private

    def template_id
      'view'
    end

    def revision
      # FIXME: `|| 0' needed?
      @rev ||= (@repository.revision(@page_name) || 0)
    end

    def body
      ToHTML.compile(@repository[@page_name])
    end
  
  end


  class ViewRevPage < Page

    def initialize(config, repo, page_name, rev)
      super config, repo, page_name
      @revision = rev
      @mtime = nil
    end

    def last_modified
      @mtime ||= @repository.mtime(@page_name, @revision)
    end

    private

    def template_id
      'viewrev'
    end

    def revision
      @revision
    end

    def body
      ToHTML.compile(@repository[@page_name, @revision])
    end
  
  end


  class DiffPage < Page

    def initialize(config, repo, page_name, rev1, rev2)
      super config, repo, page_name
      @rev1 = rev1
      @rev2 = rev2
    end

    private

    def template_id
      'diff'
    end

    def rev1
      @rev1
    end

    def rev2
      @rev2
    end

    def body
      escape_html(@repository.diff(@page_name, @rev1, @rev2))
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
