#
# $Id$
#
# Copyright (C) 2003,2004 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'bitchannel/tohtml'
require 'bitchannel/erbutils'
require 'bitchannel/textutils'

module BitChannel

  class Page
  end


  class RhtmlPage < Page
    include ErbUtils
    include TextUtils

    def initialize(config)
      @config = config
    end

    def content
      run_erb(@config.templatedir, template_id())
    end

    def type
      'text/html'
    end

    def charset
      @config.locale.charset
    end

    def last_modified
      nil
    end

    private

    def page_charset
      escape_url(@config.locale.charset)
    end

    def css_url
      escape_url(@config.css_url)
    end

    def escape_url(str)
      escape_html(URI.escape(str))
    end
  end


  class WikiPage < RhtmlPage
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

    def query_string
      ''
    end
  end


  class NamedPage < WikiPage
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


  class ViewPage < NamedPage
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
      revision() || 0
    end

    def revision
      @revision ||= @repository.revision(@page_name)
    end

    def body
      compile_page(@repository[@page_name])
    end
  end


  class ViewRevPage < NamedPage
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


  class DiffPage < NamedPage
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


  class GlobalDiffPage < WikiPage
    def initialize(config, repo, org, reload)
      super config
      @repository = repo
      @origin = org
      @reload = reload
    end

    private

    def template_id
      'gdiff'
    end

    def origin_time
      @origin
    end

    def auto_reload?
      @reload
    end

    def diffs
      @repository.diff_from(@origin).sort_by {|diff| -diff.time2.to_i }
    end
  end


  class AnnotatePage < NamedPage
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

    def annotate_revision
      @revision || @repository.revision(@page_name)
    end

    def annotate
      latest = annotate_revision()
      @repository.annotate(@page_name, @revision).map {|line|
        rev = line.slice(/\d+/).to_i
        sprintf(%Q[<a href="%s?cmd=view;rev=%d;name=%s">%4d</a>: <span class="new%d">%s</span>\n],
                @config.cgi_url, rev, page_url(), rev,
                latest - rev,
                escape_html(line.sub(/\A\s*\d+\s/, '').rstrip))
      }
    end
  end


  class HistoryPage < NamedPage
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
      @repository.logs(@page_name)
    end
  end


  class EditPage < NamedPage
    def initialize(config, repo, page_name, text, origrev, reason = nil)
      super config, repo, page_name
      @text = text
      @original_revision = origrev
      @invalid_edit_reason = reason
    end

    private

    def template_id
      'edit'
    end

    def menuitem_edit_enabled?
      false
    end

    def diff_base_revision
      @original_revision || @repository.revision(@page_name)
    rescue Errno::ENOENT
      return 0
    end
    
    def opt_message
      return nil unless @invalid_edit_reason
      @config.locale.text(@invalid_edit_reason)
    end

    def body
      @text
    end

    def original_revision
      @original_revision
    end
  end


  class PreviewPage < NamedPage
    def initialize(config, repo, page_name, text, origrev)
      super config, repo, page_name
      @text = text
      @original_revision = origrev
    end

    private

    def template_id
      'preview'
    end

    def diff_base_revision
      @original_revision || @repository.revision(@page_name)
    rescue Errno::ENOENT
      return 0
    end

    def original_revision
      @original_revision
    end

    def body
      @text
    end

    def compiled_body
      compile_page(@text)
    end
  end


  class ThanksPage < WikiPage
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


  class ListPage < WikiPage
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

    def orphan_page?(name)
      @repository.orphan?(name)
    end
  end


  class RecentPage < WikiPage
    def initialize(config, repo)
      super config
      @repository = repo
    end

    def last_modified
      @repository.latest_mtime
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


  class SearchResultPage < WikiPage
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


  class SearchErrorPage < WikiPage
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


  class TextPage < Page
    def initialize(locale, text, lm)
      @locale = locale
      @content = text
      @last_modified = lm
    end

    attr_reader :content
    attr_reader :last_modified

    def type
      'text/plain'
    end

    def charset
      @locale.charset
    end
  end

end
