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
require 'cgi'
require 'uri'
require 'date'

class CGI
  def get_param(name)
    a = params()[name]
    return nil unless a
    return nil unless a[0]
    return nil if a[0].empty?
    a[0]
  end

  def get_rev_param(name)
    rev = get_param(name).to_i
    return nil if rev < 1
    rev
  end
end

unless DateTime.method_defined?(:to_i)
  class DateTime
    def to_i
      ajd().to_i
    end
  end
end

module BitChannel

  #
  # CGI request handler class.
  # This object interprets a CGI request to the specific task.
  #
  class Handler
    include TextUtils

    def Handler.cgi_main(config, repo)
      new(config, repo).service CGI.new
    end

    def Handler.fcgi_main(config, repo)
      h = new(config, repo)
      FCGI.each_cgi do |cgi|
        h.service cgi
      end
    end

    def initialize(config, repo)
      @config = config
      @repository = repo
    end

    def service(cgi)
      begin
        handle(cgi).exec cgi
      rescue Exception => err
        error_response(err, true).exec cgi
      end
    end

    def handle(cgi)
      handler = "handle_#{cgi.get_param('cmd').to_s.downcase}"
      if respond_to?(handler, true)
      then __send__(handler, cgi)
      else view_page(cgi.get_param('name') || FRONT_PAGE_NAME)
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

      res = CGIResponse.new
      res.set_content_type 'text/html', @config.charset
      res.body = html
      res
    end

    def handle_view(cgi)
      page_name = (cgi.get_param('name') || FRONT_PAGE_NAME)
      rev = cgi.get_rev_param('rev')
      if rev
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

    def handle_edit(cgi)
      page_name = cgi.get_param('name') or return front_page()
      orgrev = @repository.revision(page_name)
      srcrev = (cgi.get_rev_param('rev') || orgrev)
      EditPage.new(@config, @repository, page_name,
                   @repository.fetch(page_name, srcrev) { '' },
                   orgrev).response
    end

    def handle_preview(cgi)
      page_name = cgi.get_param('name') or return front_page()
      text = normalize_text(cgi.get_param('text').to_s)
      orgrev = cgi.get_rev_param('origrev')
      srcrev = (cgi.get_rev_param('rev') || orgrev)
      PreviewPage.new(@config, @repository, page_name,
                      text, orgrev).response
    end

    def handle_save(cgi)
      return handle_preview(cgi) if cgi.get_param('preview')
      page_name = cgi.get_param('name') or
          return reedit_response(cgi.get_param('text').to_s,
                                 gettext(:save_without_name))
      origrev = cgi.get_rev_param('origrev')
      text = normalize_text(cgi.get_param('text').to_s)
      begin
        @repository.checkin page_name, origrev, text
        return thanks_response(page_name)
      rescue EditConflict => err
        return EditPage.new(@config, @repository,
                            page_name, err.merged,
                            @repository.revision(page_name),
                            gettext(:edit_conflicted)).response
      rescue WrongPageName => err
        return reedit(text, err.message)
      end
    end

    def normalize_text(text)
      unify_encoding(text, @config.charset).map {|line|
        detab(line).rstrip + "\r\n"
      }.join('')
    end

    def reedit_response(text, msg)
      EditPage.new(@config, @repository,
                   TMP_PAGE_NAME, text,
                   @repository.revision(TMP_PAGE_NAME), msg).response
    end

    def thanks_response(name)
      ThanksPage.new(@config, name).response
    end

    def handle_comment(cgi)
      page_name = cgi.get_param('name')
      return front_page() if not page_name or not @repository.exist?(page_name)
      uname = unify_encoding(cgi.get_param('uname').to_s.strip, @config.charset)
      comment = unify_encoding(cgi.get_param('cmt').to_s.strip, @config.charset)
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

    def handle_diff(cgi)
      page_name = cgi.get_param('name')
      return front_page() if not page_name or not @repository.exist?(page_name)
      rev1 = cgi.get_rev_param('rev1')
      rev2 = cgi.get_rev_param('rev2')
      return view_page(page_name) unless rev1 and rev2
      DiffPage.new(@config, @repository, page_name, rev1, rev2).response
    end

    GDIFF_COOKIE_NAME = 'bclastvisit'

    def handle_gdiff(cgi)
      org = cgi.get_param('org').to_s.strip
      reload = (cgi.get_param('reload').to_s.strip.downcase == 'on')
      if org.downcase == 'cookie'
        res = GlobalDiffPage.new(@config, @repository,
                last_visited(cgi) || default_origin_time(), reload).response
      else
        res = GlobalDiffPage.new(@config, @repository,
                parse_origin(org) || default_origin_time(), reload).response
      end
      now = Time.now
      res.set_cookie({'name' => GDIFF_COOKIE_NAME,
                      'value' => [now.strftime('%Y%m%d%H%M%S')],
                      'path' => (File.dirname(cgi.script_name) + '/').sub(%r</+\z>, '/'),
                      'expires' => now.getutc + 90*24*60*60})
      res
    end

    def last_visited(cgi)
      c = cgi.cookies[GDIFF_COOKIE_NAME][0] or return nil
      parse_origin(c)
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

    def default_origin_time
      DateTime.now - 3
    end

    def handle_history(cgi)
      name = cgi.get_param('name')
      return front_page() if not name or not @repository.exist?(name)
      HistoryPage.new(@config, @repository, name).response
    end

    def handle_annotate(cgi)
      name = cgi.get_param('name')
      return front_page() if not name or not @repository.exist?(name)
      rev = cgi.get_rev_param('rev')
      AnnotatePage.new(@config, @repository, name, rev).response
    end

    def handle_src(cgi)
      res = CGIResponse.new
      res.set_content_type 'text/plain', @config.charset
      name = (cgi.get_param('name') || FRONT_PAGE_NAME)
      begin
        res.last_modified = @repository.mtime(name)
      rescue Errno::ENOENT
        ;
      end
      begin
        res.body = @repository[name]
      rescue Errno::ENOENT
        res.body = ''
      end
      res
    end

    def handle_extent(cgi)
      res = CGIResponse.new
      res.set_content_type 'text/plain', @config.charset
      res.last_modified = @repository.latest_mtime
      buf = ''
      @repository.page_names.sort.each do |name|
        buf << "= #{name}\r\n"
        buf << "\r\n"
        buf << @repository[name]
        buf << "\r\n"
      end
      res.body = buf
      res
    end

    def handle_list(cgi)
      ListPage.new(@config, @repository).response
    end

    def handle_recent(cgi)
      RecentPage.new(@config, @repository).response
    end

    def handle_search(cgi)
      begin
        regs = setup_query(cgi.get_param('q'))
        SearchResultPage.new(@config, @repository,
                             cgi.get_param('q'), regs).response
      rescue WrongQuery => err
        return SearchErrorPage.new(@config, cgi.get_param('q'), err).response
      end
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

    def check_pattern(pat)
      raise WrongQuery, 'no pattern' unless pat
      raise WrongQuery, 'empty pattern' if pat.empty?
      raise WrongQuery, "pattern too short: #{pat}" if pat.length < 2
      raise WrongQuery, 'pattern too long' if pat.length > 128
    end
  end

  class CGIResponse
    def initialize
      @status = nil
      @header = {}
      @body = nil
      @cookies = []
    end

    attr_accessor :status
    attr_accessor :body

    def set_content_type(t, charset = nil)
      @header['type'] = t
      @header['charset'] = charset if charset
    end

    def content_type
      if @header['charset']
        "#{@header['type']}; charset=#{@header['charset']}"
      else
        @header['type']
      end
    end

    def last_modified=(tm)
      if tm
        @header['Last-Modified'] = CGI.rfc1123_date(tm)
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

    def set_cookie(spec)
      @cookies.push spec
    end

    def exec(cgi)
      @header['status'] = @status if @status
      @header['Content-Length'] = @body.length.to_s
      @header['cookie'] = @cookies.map {|spec| CGI::Cookie.new(spec) }
      print cgi.header(@header)
      case cgi.request_method.to_s.upcase
      when 'GET', 'POST', ''
        print @body
      end
      STDOUT.flush
    end
  end

  class GenericPage   # redefine
    def response
      res = CGIResponse.new
      res.no_cache = true
      res.last_modified = last_modified()
      res.set_content_type 'text/html', charset()
      res.body = html()
      res
    end
  end

end   # module BitChannel
