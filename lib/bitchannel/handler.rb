#
# $Id$
#
# Copyright (C) 2003,2004 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'bitchannel/page'
require 'bitchannel/textutils'
require 'bitchannel/config'
require 'webrick/cookie'
require 'uri'
require 'date'
require 'time'

unless DateTime.method_defined?(:to_i)
  class DateTime
    def to_i
      ajd().to_i
    end
  end
end

module BitChannel

  class Handler
    include TextUtils

    def initialize(config, repo)
      @config = config
      @repository = repo
    end

    def service(req, webrickres)
      begin
        handle(req).update_for webrickres
      rescue Exception => err
        error_response(err, true).update_for webrickres
      end
    end

    def handle(req)
      mid = "handle_#{req.cmd}"
      if respond_to?(mid, true)
      then __send__(mid, req)
      else view_page(req.page_name || FRONT_PAGE_NAME)
      end
    rescue WrongPageName => err
      error_response(err, false)
    end

    private

    def error_response(err, debugp)
      html = "<html><head><title>Error</title></head><body>\n" +
             "<pre>BitChannel Error\n"
      if debugp
        html << escape_html("#{err.message} (#{err.class})\n")
        html << escape_html(err.precise_message) << "\n" \
            if err.respond_to?(:precise_message)
        err.backtrace.each do |i|
          html << escape_html(i) << "\n"
        end
      else
        html << escape_html(err.message) << "\n"
        html << escape_html(err.precise_message) << "\n" \
            if err.respond_to?(:precise_message)
      end
      html << "</pre>\n</body></html>"

      res = Response.new
      res.set_content_body html, 'text/html', @config.charset
      res
    end

    def handle_view(req)
      page_name = (req.page_name || FRONT_PAGE_NAME)
      if rev = req.rev
      then ViewRevPage.new(@config, @repository, page_name, rev).response
      else view_page(page_name)
      end
    end

    def view_page(name)
      if not @repository.exist?(name) and @repository.valid?(name)
        return EditPage.new(@config, @repository, name, '', nil).response
      end
      ViewPage.new(@config, @repository, name).response
    end

    def front_page
      ViewPage.new(@config, @repository, FRONT_PAGE_NAME).response
    end

    def handle_edit(req)
      page_name = req.page_name or return front_page()
      orgrev = @repository.revision(page_name)
      srcrev = (req.rev || orgrev)
      EditPage.new(@config, @repository, page_name,
                   @repository.fetch(page_name, srcrev) { '' },
                   orgrev).response
    end

    def handle_preview(req)
      page_name = req.page_name or return front_page()
      PreviewPage.new(@config, @repository,
                      page_name, req.normalized_text, req.origrev).response
    end

    def handle_save(req)
      return handle_preview(req) if req.preview?
      page_name = req.page_name or
          return reedit_response(req.normalized_text, @config.text(:save_without_name))
      text = req.normalized_text
      begin
        @repository.checkin page_name, req.origrev, text
        return thanks_response(page_name)
      rescue EditConflict => err
        return EditPage.new(@config, @repository,
                            page_name, err.merged,
                            @repository.revision(page_name),
                            @config.text(:edit_conflicted)).response
      rescue WrongPageName => err
        return reedit(text, err.message)
      end
    end

    def reedit_response(text, msg)
      EditPage.new(@config, @repository,
                   TMP_PAGE_NAME, text,
                   @repository.revision(TMP_PAGE_NAME), msg).response
    end

    def thanks_response(name)
      ThanksPage.new(@config, name).response
    end

    def handle_comment(req)
      page_name = req.page_name
      return front_page() if not page_name or not @repository.exist?(page_name)
      uname = req.cmtbox_username
      comment = req.cmtbox_comment
      @repository.edit(page_name) {|text|
        insert_comment(@repository[page_name], uname, comment)
      }
      thanks_response(page_name)
    end

    def insert_comment(text, uname, comment)
      cmtline = "* #{format_time(Time.now)}: #{uname}: #{comment}"
      unless /\[\[\#comment(:.*?)?\]\]/n =~ text
        text << "\n" << cmtline
        return text
      end
      text.sub(/\[\[\#comment(:.*?)?\]\]/n) { $& + "\n" + cmtline }
    end

    def handle_diff(req)
      page_name = req.page_name
      return front_page() if not page_name or not @repository.exist?(page_name)
      rev1 = req.rev1
      rev2 = req.rev2
      return view_page(page_name) unless rev1 and rev2
      DiffPage.new(@config, @repository, page_name, rev1, rev2).response
    end

    def handle_gdiff(req)
      org = case
            when req.gdiff_whatsnew_mode?    then req.gdiff_last_visited
            when req.gdiff_origin_specified? then req.gdiff_origin_time
            else default_origin_time()
            end
      res = GlobalDiffPage.new(@config, @repository,
                               org, req.gdiff_reload?).response
      res.set_cookie req.new_gdiff_cookie
      res
    end

    def default_origin_time
      DateTime.now - 3
    end

    def handle_history(req)
      name = req.page_name
      return front_page() if not name or not @repository.exist?(name)
      HistoryPage.new(@config, @repository, name).response
    end

    def handle_annotate(req)
      name = req.page_name
      return front_page() if not name or not @repository.exist?(name)
      AnnotatePage.new(@config, @repository, name, req.rev).response
    end

    def handle_src(req)
      res = Response.new
      name = (req.page_name || FRONT_PAGE_NAME)
      begin
        res.last_modified = @repository.mtime(name)
      rescue Errno::ENOENT
        ;
      end
      begin
        res.set_content_body @repository[name], 'text/plain', @config.charset
      rescue Errno::ENOENT
        res.set_content_body '', 'text/plain', @config.charset
      end
      res
    end

    def handle_extent(req)
      buf = ''
      @repository.page_names.sort.each do |name|
        buf << "= #{name}\r\n"
        buf << "\r\n"
        buf << @repository[name]
        buf << "\r\n"
      end
      res = Response.new
      res.last_modified = @repository.latest_mtime
      res.set_content_body buf, 'text/plain', @config.charset
      res
    end

    def handle_list(req)
      ListPage.new(@config, @repository).response
    end

    def handle_recent(req)
      RecentPage.new(@config, @repository).response
    end

    def handle_search(req)
      begin
        SearchResultPage.new(@config, @repository,
                             req.search_query, req.search_regexps).response
      rescue WrongQuery => err
        return SearchErrorPage.new(@config, req.search_query, err).response
      end
    end
  end


  class Request
    include TextUtils

    def initialize(req, config, servlet_p)
      @request = req
      @config = config
      @servlet_p = servlet_p
    end

    def cmd
      get('cmd').to_s.downcase
    end

    def page_name
      return get('name') unless @servlet_p
      if @request.query['name']
        get('name')
      else
        n = @request.path.split('/').last
        return nil unless n
        return nil if n.empty?
        n.sub(/\.html\z/, '')
      end
    end

    def normalized_text
      normalize_text(get('text').to_s)
    end

    def cmtbox_username
      unify_encoding(get('uname').to_s.strip, @config.charset)
    end

    def cmtbox_comment
      normalize_text(get('cmt').to_s.strip)
    end

    def preview?
      get('preview') ? true : false
    end

    def rev
      getrev('rev')
    end

    def rev1
      getrev('rev1')
    end

    def rev2
      getrev('rev2')
    end

    def origrev
      getrev('orgrev')
    end

    def getrev(name)
      rev = get(name).to_i
      return nil if rev < 1
      rev
    end
    private :getrev

    def gdiff_origin_time
      parse_origin(get('org').to_s.strip)
    end

    def gdiff_reload?
      get('reload').to_s.strip.downcase == 'on'
    end

    def gdiff_whatsnew_mode?
      get('org').to_s.strip.downcase == 'cookie' and
          not gdiff_last_visited().nil?
    end

    def gdiff_last_visited
      c = gdiff_cookie() or return nil
      parse_origin(c.value)
    end

    def parse_origin(org)
      re = /\A(\d\d\d\d)(\d\d)(?:(\d\d)(?:(\d\d)(?:(\d\d)(\d\d)?)?)?)?\z/
      m = re.match(org.sub(/[\s\-:T]+/, '').sub(/\+.*/, '')) or return nil
      begin
        # we should use Time, to avoid CVS error.
        return Time.local(*m.captures.map {|s| s.to_i })
      rescue ArgumentError   # time out of range
        return nil
      end
    end
    private :parse_origin

    GDIFF_COOKIE_NAME = 'bclastvisit'

    def gdiff_cookie
      @request.cookies.detect {|c| c.name == GDIFF_COOKIE_NAME }
    end

    def new_gdiff_cookie
      now = Time.now
      c = WEBrick::Cookie.new(GDIFF_COOKIE_NAME, now.strftime('%Y%m%d%H%M%S'))
      c.path = (File.dirname(@request.script_name) + '/').sub(%r</+\z>, '/')
      c.expires = now.getutc + 90*24*60*60
      c
    end

    def search_query
      unify_encoding(get('q').to_s.strip, @config.charset)
    end

    def search_regexps
      setup_query(search_query())
    end

    def setup_query(query)
      raise WrongQuery, 'no pattern' unless query
      patterns = jsplit(query).map {|pat|
        check_pattern pat
        /#{Regexp.quote(pat)}/ie
      }
      raise WrongQuery, 'no pattern' if patterns.empty?
      raise WrongQuery, 'too many sub patterns' if patterns.length > 8
      patterns
    end
    private :setup_query

    def check_pattern(pat)
      raise WrongQuery, 'no pattern' unless pat
      raise WrongQuery, 'empty pattern' if pat.empty?
      raise WrongQuery, "pattern too short: #{pat}" if pat.length < 2
      raise WrongQuery, 'pattern too long' if pat.length > 128
    end
    private :check_pattern

    private

    def normalize_text(text)
      unify_encoding(text, @config.charset).map {|line|
        detab(line).rstrip + "\r\n"
      }.join('')
    end

    def get(name)
      data = @request.query[name]
      return nil unless data
      return nil if data.empty?
      data.to_s
    end
  end


  class Response
    def initialize
      @status = nil
      @header = {}
      @cookies = []
      @body = nil
      self.no_cache = true
    end

    attr_accessor :status
    attr_reader :body

    def set_content_body(body, type, charset)
      @body = body
      @header['Content-Type'] = "#{type}; charset=#{charset}"
    end

    def content_type
      @header['Content-Type']
    end

    def last_modified=(tm)
      if tm
        @header['Last-Modified'] = tm.httpdate
      else
        @header.delete 'Last-Modified'
      end
    end

    def last_modified
      @header['Last-Modified']
    end

    def no_cache=(no)
      if no
        @header['Cache-Control'] = 'no-cache'
        @header['Pragma'] = 'no-cache'
      else
        @header.delete 'Cache-Control'
        @header.delete 'no-cache'
      end
    end

    def no_cache?
      @header['Cache-Control'] ? true : false
    end

    def set_cookie(c)
      @cookies.push c
    end

    def update_for(webrickres)
      webrickres.status = @status if @status
      @header.each do |k, v|
        webrickres[k] = v
      end
      webrickres.cookies.replace @cookies
      webrickres.body = @body
    end
  end


  class GenericPage   # redefine
    def response
      res = Response.new
      res.last_modified = last_modified()
      res.set_content_body html(), 'text/html', charset()
      res
    end
  end

end   # module BitChannel
