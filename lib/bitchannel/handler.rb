#
# $Id$
#
# Copyright (C) 2003,2004 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'bitchannel/config'
require 'bitchannel/page'
require 'bitchannel/textutils'
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

    def initialize(wiki)
      @wiki = wiki
    end

    def handle(req)
      handle_request(req) || @wiki.view(FRONT_PAGE_NAME).response
    rescue Exception => err
      error_response(err, true)
    end

    def handle_request(req)
      mid = "handle_#{req.cmd}"
      return nil unless respond_to?(mid, true)
      __send__(mid, req)
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
      res.set_content_body html, 'text/html', @wiki.locale.charset
      res
    end

    def handle_view(req)
      if req.rev
      then __handle_viewrev(req)
      else __handle_view_latest(req)
      end
    end

    def __handle_view_latest(req)
      return nil unless req.page_name
      return nil unless @wiki.valid?(req.page_name)
      unless @wiki.exist?(req.page_name)
        return @wiki.edit_new(req.page_name).response
      end
      @wiki.view(req.page_name).response
    end

    def __handle_viewrev(req)
      return nil unless req.page_name
      return nil unless @wiki.exist?(req.page_name)
      @wiki.viewrev(req.page_name, req.rev).response
    end

    def handle_edit(req)
      return nil unless req.page_name
      return nil unless @wiki.valid?(req.page_name)
      if req.rev
      then @wiki.edit_revision(req.page_name, req.rev).response
      else @wiki.edit(req.page_name).response
      end
    end

    def handle_save(req)
      return invalid_edit(req.normalized_text, :save_without_name) \
          unless req.page_name
      return invalid_edit(req.normalized_text, :invalid_page_name) \
          unless @wiki.valid?(req.page_name)
      return __handle_preview(req) if req.preview?
      begin
        text = req.normalized_text
        @wiki.save(req.page_name, req.origrev, text).response
      rescue EditConflict => err
        @wiki.edit_again(req.page_name, err.merged, err.revision).response
      end
    end

    def __handle_preview(req)
      @wiki.preview(req.page_name, req.normalized_text, req.origrev).response
    end

    def invalid_edit(text, reason)
      @wiki.edit_again(TMP_PAGE_NAME, text, nil, reason).response
    end

    def handle_comment(req)
      return nil unless req.page_name
      return nil unless @wiki.exist?(req.page_name)
      @wiki.comment(req.page_name, req.cmtbox_username, req.cmtbox_comment).response
    end

    def handle_diff(req)
      return nil unless req.page_name
      return nil unless @wiki.exist?(req.page_name)
      return nil unless req.rev1 and req.rev2
      @wiki.diff(req.page_name, req.rev1, req.rev2).response
    end

    def handle_gdiff(req)
      org = case
            when req.gdiff_whatsnew_mode?    then req.gdiff_last_visited
            when req.gdiff_origin_specified? then req.gdiff_origin_time
            else default_origin_time()
            end
      res = @wiki.gdiff(org, req.gdiff_reload?).response
      res.set_cookie req.new_gdiff_cookie
      res
    end

    def default_origin_time
      DateTime.now - 3
    end

    def handle_history(req)
      return nil unless req.page_name
      return nil unless @wiki.exist?(req.page_name)
      @wiki.history(req.page_name).response
    end

    def handle_annotate(req)
      return nil unless req.page_name
      return nil unless @wiki.exist?(req.page_name)
      @wiki.annotate(req.page_name, req.rev).response
    end

    def handle_src(req)
      return not_found() unless req.page_name
      return not_found() unless @wiki.exist?(req.page_name)
      @wiki.src(req.page_name).response
    end

    def not_found
      nil   # FIXME
    end

    def handle_extent(req)
      @wiki.extent.response
    end

    def handle_list(req)
      @wiki.list.response
    end

    def handle_recent(req)
      @wiki.recent.response
    end

    def handle_search(req)
      @wiki.search(req.search_query, req.search_regexps).response
    rescue WrongQuery => err
      @wiki.search_error(req.search_query, err).response
    end
  end


  class Request
    include TextUtils

    def initialize(req, locale, pathinfo_sensitive)
      @request = req
      @locale = locale
      @pathinfo_sensitive = pathinfo_sensitive
    end

    def cmd
      get('cmd').to_s.downcase
    end

    def page_name
      return get('name') unless @pathinfo_sensitive
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
      @locale.unify_encoding(get('uname').to_s.strip)
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
      @locale.unify_encoding(get('q').to_s.strip)
    end

    def search_regexps
      setup_query(search_query())
    end

    def setup_query(query)
      raise WrongQuery, 'no pattern' unless query
      patterns = @locale.split_words(query).map {|pat|
        check_pattern pat
        /#{Regexp.quote(pat)}/i
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
      @locale.unify_encoding(text).map {|line|
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
    def Response.new_from_page(page)
      res = new()
      res.last_modified = page.last_modified
      res.set_content_body page.content, page.type, page.charset
      res
    end

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
      @header.key?('Cache-Control')
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


  class Page   # redefine
    def response
      Response.new_from_page(self)
    end
  end

end   # module BitChannel
