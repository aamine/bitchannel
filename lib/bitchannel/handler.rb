#
# $Id$
#
# Copyright (C) 2003 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'bitchannel/page'
require 'bitchannel/textutils'
require 'cgi'
require 'uri'

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

module BitChannel

  def BitChannel.cgi_main(config, repo)
    Handler.new(config, repo).handle_request(CGI.new)
  end

  #
  # CGI request handler class.
  # This object interprets a CGI request to the specific task.
  #
  class Handler
    include TextUtils

    def initialize(config, repo)
      @config = config
      @repository = repo
    end

    def handle_request(cgi)
      begin
        wiki_main cgi
      rescue Exception => err
        res = error_response(err, true)
        res.exec cgi
      end
    end

    private

    def wiki_main(cgi)
      res = case cgi.get_param('cmd').to_s.downcase
            when 'view'     then handle_view(cgi)
            when 'edit'     then handle_edit(cgi)
            when 'save'     then handle_save(cgi)
            when 'diff'     then handle_diff(cgi)
            when 'history'  then handle_history(cgi)
            when 'annotate' then handle_annotate(cgi)
            when 'src'      then handle_src(cgi)
            when 'list'     then handle_list(cgi)
            when 'recent'   then handle_recent(cgi)
            when 'search'   then handle_search(cgi)
            else
              view_page(cgi.get_param('name') || FRONT_PAGE_NAME)
            end
      res.exec cgi
    rescue WrongPageName => err
      res = error_response(err, false)
      res.exec cgi
    end

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

    def handle_save(cgi)
      page_name = cgi.get_param('name') or
          return reedit_response(cgi.get_param('text').to_s,
                                 gettext(:save_without_name))
      origrev = cgi.get_rev_param('origrev')
      text = normalize_text(cgi.get_param('text').to_s)
      begin
        @repository.checkin page_name, origrev, text
        thanks_response(page_name)
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
      text.map {|line| detab(line).rstrip + "\r\n" }.join('')
    end

    def reedit_response(text, msg)
      EditPage.new(@config, @repository,
                   TMP_PAGE_NAME, text,
                   @repository.revision(TMP_PAGE_NAME), msg).response
    end

    def thanks_response(name)
      ThanksPage.new(@config, name).response
    end

    def handle_diff(cgi)
      page_name = cgi.get_param('name')
      return front_page() if not page_name or not @repository.exist?(page_name)
      rev1 = cgi.get_rev_param('rev1')
      rev2 = cgi.get_rev_param('rev2')
      return view_page(page_name) unless rev1 and rev2
      DiffPage.new(@config, @repository, page_name, rev1, rev2).response
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
    end

    attr_accessor :status
    attr_accessor :body

    def set_content_type(t, charset = nil)
      @header['type'] = t
      @header['charset'] = charset if charset
    end

    def last_modified=(tm)
      if tm
        @header['Last-Modified'] = CGI.rfc1123_date(tm)
      else
        @header.delete 'Last-Modified'
      end
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

    def exec(cgi)
      @header['status'] = @status if @status
      @header['Content-Length'] = @body.length.to_s
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
      res.set_content_type 'text/html', page_charset()
      res.body = html()
      res
    end
  end

end   # module BitChannel
