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
      erb = ERB.new(get_template(@config.templatedir, template_id()))
      erb.filename = "#{template_id()}.rhtml"
      erb.result(binding())
    end

    private

    def get_template(tmpldir, tmplname)
      File.read("#{tmpldir}/#{tmplname}.rhtml").gsub(/^\.include (\w+)/) {
        get_template(tmpldir, $1)
      }
    end

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

    def query_string
      ''
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

    def diff
      @repository.diff(@page_name, @rev1, @rev2)
    end
  end


  class AnnotatePage < Page
    def initialize(config, repo, page_name, rev)
      super config, repo, page_name
      @revision = rev
    end

    private

    def template_id
      'annotate'
    end

    def revision
      @revision
    end

    def annotate
      @repository.annotate(@page_name, @revision)
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


  class EditPage < Page
    def initialize(config, repo, page_name, text, origrev, msg = nil)
      super config, repo, page_name
      @text = text
      @original_revision = origrev
      @opt_message = msg
    end

    private

    def template_id
      'edit'
    end
    
    def opt_message
      @opt_message
    end

    def body
      @text
    end

    def original_revision
      @original_revision
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


  class SearchResultPage < GenericPage
    def initialize(config, repo, q, patterns)
      super config, repo
      @query_string = q
      @patterns = patterns
    end

    private

    def template_id
      'search_result'
    end

    def query_string
      escape_html(jsplit(@query_string).join(' '))
    end

    def matched_pages(&block)
      title_match, not_match = @repository.entries.sort.partition {|name|
        @patterns.all? {|re| re =~ name }
      }
      title_match.each do |name|
        yield name, @repository[name]
      end
      not_match.sort_by {|name| -@repository.mtime(name).to_i }.each do |name|
        content = @repository[name]
        if @patterns.all? {|re| re =~ content }
          yield name, content
        end
      end
    end

    def shorten(str)
      escape_html(str.slice(/\A.{0,60}/m).delete('[]*').gsub(/\s+/, ' ').strip)
    end
  end


  class SearchErrorPage < GenericPage
    def initialize(config, repo, query, err)
      super config, repo
      @query = query
      @error = err
    end

    private

    def template_id
      'search_error'
    end

    def error_message
      escape_html(@error.message)
    end

    def query_string
      escape_html(Array(@query).join(' '))
    end
  end

end
