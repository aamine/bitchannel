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

class ERB   # tmp
  attr_accessor :filename  unless method_defined?(:filename)

  remove_method :result
  def result(binding)
    eval(@src, binding, @filename, 1)
  end
end

module Wikitik

  class GenericPage
    include TextUtils

    def initialize(config, repo)
      @config = config
      @repository = repo
    end

    def html
      erb = ERB.new(@config.read_rhtml(template_id()))
      erb.filename = "#{template_id()}.rhtml"
      erb.result(binding())
    end

    private

    def charset
      url(@config.charset)
    end

    def css_url
      url(@config.css_url)
    end

    def cgi_url
      url(@config.cgi_url)
    end

    def url(str)
      escape_html(URI.escape(str))
    end
  end


  # a page object which is associated with a real file
  class Page < GenericPage
    def initialize(config, repo, page_name)
      super config, repo
      @page_name = page_name

      # cache
      @size = nil
      @mtime = nil
      @links = nil
      @revlinks = nil
      @nlinks = {}
    end

    private

    def compile_page(content)
      ToHTML.new(@config, @repository).compile(content, @page_name)
    end

    def page_name
      escape_html(@page_name)
    end

    def page_url
      url(@page_name)
    end

    def size
      @size ||= @repository.size(@page_name)
    end

    def mtime
      @mtime ||= @repository.mtime(@page_name)
    end

    def links
      @links ||= @repository.links(@page_name)
    end

    def reverse_links
      @revlinks ||= (@repository.reverse_links(@page_name) - [@page_name])
    end

    def ordered_reverse_links
      leaves, nodes = reverse_links().partition {|page| num_links(page) < 2 }
      nodes.sort_by {|page| @repository.size(page) / num_links(page) } +
        leaves.sort_by {|page| -@repository.size(page) }
    end

    def num_links(page)
      @nlinks[page] ||= @repository.links(page).size
    end

    def num_revlinks
      reverse_links().size
    end
  end


  class ViewPage < Page
    def initialize(config, repo, page_name)
      super
      @revision = nil
    end

    def last_modified
      mtime()
    end

    private

    def template_id
      'view'
    end

    def revision
      # FIXME: `|| 0' needed?
      @revision ||= (@repository.revision(@page_name) || 0)
    end

    def body
      compile_page(@repository[@page_name])
    end
  end


  class ViewRevPage < Page
    def initialize(config, repo, page_name, rev)
      super config, repo, page_name
      @revision = rev
    end

    def last_modified
      mtime()
    end

    private

    def template_id
      'viewrev'
    end

    def revision
      @revision
    end

    def body
      compile_page(@repository[@page_name, @revision])
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
      @revision = rev || @repository.revision(@page_name)
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

    def revision
      @revision || 0
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


  class ListPage < GenericPage
    private

    def template_id
      'list'
    end

    def page_list
      @repository.entries.sort_by {|n| n.downcase }.map {|n| escape_html(n) }
    end
  end


  class RecentPage < GenericPage
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

end
