#
# $Id$
#
# Copyright (C) 2003 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'bitchannel/tohtml'
require 'bitchannel/textutils'
require 'erb'

class ERB   # tmp
  attr_accessor :filename  unless method_defined?(:filename)

  remove_method :result
  def result(binding)
    eval(@src, binding, @filename, 1)
  end
end

module BitChannel

  class GenericPage
    include TextUtils

    def initialize(config)
      @config = config
    end

    def html
      erb = ERB.new(get_template(@config.templatedir, template_id()), nil, 2)
      erb.filename = "#{template_id()}.rhtml"
      erb.result(binding())
    end

    def last_modified
      nil
    end

    def charset
      @config.charset
    end

    private

    def menuitem_diff_enabled?()     false end
    def menuitem_annotate_enabled?() false end
    def menuitem_history_enabled?()  false end
    def menuitem_edit_enabled?()     false end
    def menuitem_list_enabled?()     true end
    def menuitem_recent_enabled?()   true end
    def menuitem_top_enabled?()      true end
    def menuitem_help_enabled?()     true end
    def menuitem_search_enabled?()   true end

    def get_template(tmpldir, tmplname)
      File.read("#{tmpldir}/#{tmplname}.rhtml").gsub(/^\.include (\w+)/) {
        get_template(tmpldir, $1.untaint)
      }.untaint
    end

    def page_charset
      escape_url(@config.charset)
    end

    def css_url
      escape_url(@config.css_url)
    end

    def cgi_url
      escape_url(@config.cgi_url)
    end

    def logo_url
      u = @config.logo_url
      u ? %[<img class="sitelogo" src="#{escape_html(u)}" alt=""> ] : ''
    end

    def index_page_url
      view_url(FRONT_PAGE_NAME)
    end

    def help_page_url
      view_url(HELP_PAGE_NAME)
    end

    def view_url(page_name)
      if @config.html_url?
      then "#{escape_url(page_name)}.html"
      else "#{cgi_url()}?cmd=view;name=#{escape_url(page_name)}"
      end
    end

    def escape_url(str)
      escape_html(URI.escape(str))
    end

    def query_string
      ''
    end
  end


  # a page object which is associated with a real file
  class Page < GenericPage
    def initialize(config, repo, page_name)
      super config
      @repository = repo
      @page_name = page_name

      # cache
      @size = nil
      @mtime = nil
      @links = nil
      @revlinks = nil
      @nlinks = {}
    end

    private

    def menuitem_edit_enabled?()     true end
    def menuitem_diff_enabled?()     diff_base_revision() > 1 end
    def menuitem_history_enabled?()  true end
    def menuitem_annotate_enabled?() true end

    def compile_page(content)
      ToHTML.new(@config, @repository).compile(content, @page_name)
    end

    def page_name
      escape_html(@page_name)
    end

    def page_url
      escape_url(@page_name)
    end

    def page_view_url
      view_url(@page_name)
    end

    def front_page?
      @page_name == FRONT_PAGE_NAME
    end

    def site_name
      escape_html(@config.site_name)
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

    def revlinks
      @revlinks ||= (@repository.revlinks(@page_name) - [@page_name])
    end

    def ordered_revlinks
      leaves, nodes = revlinks().select {|page| @repository.exist?(page) }\
                          .partition {|page| num_links(page) < 2 }
      nodes.sort_by {|page| @repository.size(page) / num_links(page) } +
          leaves.sort_by {|page| -@repository.size(page) }
    end

    def num_links(page)
      @nlinks[page] ||= @repository.links(page).size
    end

    def num_revlinks
      revlinks().size
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

    def menuitem_top_enabled?()
      page_name() != FRONT_PAGE_NAME
    end

    def menuitem_help_enabled?()
      page_name() != HELP_PAGE_NAME
    end

    def diff_base_revision
      revision()
    end

    def revision
      @revision ||= @repository.revision(@page_name)
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

    def diff_base_revision
      revision()
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

    def diff_base_revision
      rev1()
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

    def menuitem_annotate_enabled?
      false
    end

    def diff_base_revision
      @revision || @repository.revision(@page_name)
    end

    def revision
      @revision
    end

    def annotate
      @repository.annotate(@page_name, @revision).map {|data|
        rev = data.slice(/\A\s*\d+/)
        line = data.sub(/\A\s*\d+\s/, '')
        %Q[<a href="#{@config.cgi_url}?cmd=view;rev=#{rev.to_i};name=#{page_url()}">#{rev}</a>: #{escape_html(line)}]
      }
    end
  end


  class HistoryPage < Page
    def initialize(config, repo, page_name)
      super
      @revision = nil
    end

    private

    def template_id
      'history'
    end

    def menuitem_history_enabled?
      false
    end

    def diff_base_revision
      revision() || 0
    end

    def revision
      @revision ||= @repository.revision(@page_name)
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

    def menuitem_edit_enabled?
      false
    end

    def diff_base_revision
      @original_revision || @repository.revision(@page_name) || 0
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


  class ThanksPage < GenericPage
    def initialize(config, page_name)
      super config
      @page_name = page_name
    end

    private

    def template_id
      'thanks'
    end

    def page_view_url
      # We cannot use ';' here.
      if @config.html_url?
      then "#{escape_url(@page_name)}.html"
      else "#{cgi_url()}?name=#{escape_url(@page_name)}"
      end
    end
  end


  class ListPage < GenericPage
    def initialize(config, repo)
      super config
      @repository = repo
    end

    private

    def template_id
      'list'
    end

    def menuitem_list_enabled?
      false
    end

    def page_list
      @repository.entries.sort_by {|name| name.downcase }
    end
  end


  class RecentPage < GenericPage
    def initialize(config, repo)
      super config
      @repository = repo
    end

    private

    def template_id
      'recent'
    end

    def menuitem_recent_enabled?
      false
    end

    def page_list
      @repository.entries\
          .map {|name| [name, @repository.mtime(name)] }\
          .sort_by {|name, mtime| -(mtime.to_i) }
    end
  end


  class SearchResultPage < GenericPage
    def initialize(config, repo, q, patterns)
      super config
      @repository = repo
      @query_string = q
      @patterns = patterns
    end

    private

    def template_id
      'search_result'
    end

    def menuitem_search_enabled?
      false
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
    def initialize(config, query, err)
      super config
      @query = query
      @error = err
    end

    private

    def template_id
      'search_error'
    end

    def menuitem_search_enabled?
      false
    end

    def error_message
      escape_html(@error.message)
    end

    def query_string
      escape_html(Array(@query).join(' '))
    end
  end

end
