#
# $Id$
#
# Copyright (C) 2003 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.
#

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
        send_error cgi, err, true  #$DEBUG
      end
    end

    private

    def wiki_main(cgi)
      case cgi.get_param('cmd').to_s.downcase
      when 'view'     then handle_view cgi
      when 'edit'     then handle_edit cgi
      when 'save'     then handle_save cgi
      when 'diff'     then handle_diff cgi
      when 'history'  then handle_history cgi
      when 'annotate' then handle_annotate cgi
      when 'src'      then handle_src cgi
      when 'list'     then handle_list cgi
      when 'recent'   then handle_recent cgi
      when 'search'   then handle_search cgi
      else
        view cgi, (cgi.get_param('name') || @config.index_page_name)
      end
    rescue WrongPageName => err
      send_error cgi, err, false
    end

    def handle_view(cgi)
      page_name = (cgi.get_param('name') || @config.index_page_name)
      rev = cgi.get_rev_param('rev')
      if rev
        page = ViewRevPage.new(@config, @repository, page_name, rev)
        send_html cgi, page.html, page.last_modified
      else
        view cgi, page_name
      end
    end

    def handle_edit(cgi)
      page_name = cgi.get_param('name')
      unless page_name
        view cgi, @config.index_page_name
        return
      end
      orgrev = @repository.revision(page_name)
      srcrev = (cgi.get_rev_param('rev') || orgrev)
      send_html cgi, EditPage.new(@config, @repository,
                                  page_name,
                                  @repository.fetch(page_name, srcrev) { '' },
                                  orgrev).html
    end

    def handle_save(cgi)
      page_name = cgi.get_param('name')
      unless page_name
        reedit cgi, cgi.get_param('text').to_s, gettext(:save_without_name)
        return
      end
      begin
        text = cgi.get_param('text').to_s.gsub(/\r\n|\n|\r/, "\r\n")
        @repository.checkin page_name,
                            cgi.get_rev_param('origrev'),
                            text
        thanks cgi, page_name
      rescue EditConflict => err
        send_html cgi, EditPage.new(@config, @repository,
                                    page_name,
                                    err.merged,
                                    @repository.revision(page_name),
                                    gettext(:edit_conflicted)).html
      rescue WrongPageName => err
        reedit cgi, text, err.message
      end
    end

    def reedit(cgi, text, msg)
      send_html cgi, EditPage.new(@config, @repository,
                                  @config.tmp_page_name,
                                  text,
                                  @repository.revision(@config.tmp_page_name),
                                  msg).html
    end

    def thanks(cgi, page_name)
      send_html cgi, <<-ThanksPage
        <html>
        <head>
        <meta http-equiv="refresh" content="1;url=#{@config.cgi_url}?name=#{URI.encode(page_name)}">
        <title>Moving...</title>
        </head>
        <body>
        <p>Thank you for your edit.
        Wait or <a href="#{@config.cgi_url}?cmd=view;name=#{URI.encode(page_name)}">click here</a> to return to the page.</p>
        </body>
        </html>
      ThanksPage
    end

    def handle_diff(cgi)
      page_name = cgi.get_param('name')
      if not page_name or not @repository.exist?(page_name)
        view cgi, @config.index_page_name
        return
      end
      rev1 = cgi.get_rev_param('rev1')
      rev2 = cgi.get_rev_param('rev2')
      unless rev1 and rev2
        view cgi, page_name
        return
      end
      send_html cgi, DiffPage.new(@config, @repository,
                                  page_name, rev1, rev2).html
    end

    def handle_history(cgi)
      page_name = cgi.get_param('name')
      if not page_name or not @repository.exist?(page_name)
        view cgi, @config.index_page_name
        return
      end
      send_html cgi, HistoryPage.new(@config, @repository, page_name).html
    end

    def handle_annotate(cgi)
      page_name = cgi.get_param('name')
      if not page_name or not @repository.exist?(page_name)
        view cgi, @config.index_page_name
        return
      end
      rev = cgi.get_rev_param('rev')
      send_html cgi, AnnotatePage.new(@config, @repository, page_name, rev).html
    end

    def handle_src(cgi)
      page_name = (cgi.get_param('name') || @config.index_page_name)
      begin
        body = @repository[page_name]
      rescue Errno::ENOENT
        body = ''
      end
      begin
        mtime = @repository.mtime(page_name)
      rescue Errno::ENOENT
        mtime = nil
      end
      send_text cgi, body, mtime
    end

    def handle_list(cgi)
      send_html cgi, ListPage.new(@config, @repository).html
    end

    def handle_recent(cgi)
      send_html cgi, RecentPage.new(@config, @repository).html
    end

    def handle_search(cgi)
      begin
        regs = setup_query(cgi.get_param('q'))
        send_html cgi, SearchResultPage.new(@config, @repository,
                                            cgi.get_param('q'), regs).html
      rescue WrongQuery => err
        send_html cgi, SearchErrorPage.new(@config, @repository,
                                           cgi.get_param('q'), err).html
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

    def view(cgi, page_name)
      if not @repository.exist?(page_name) and @repository.valid?(page_name)
        send_html cgi, EditPage.new(@config, @repository,
                                    page_name, '', nil).html
        return
      end
      page = ViewPage.new(@config, @repository, page_name)
      send_html cgi, page.html, page.last_modified
    end

    def send_html(cgi, html, mtime = nil)
      send_page cgi, html, 'text/html', mtime
    end

    def send_text(cgi, text, mtime = nil)
      send_page cgi, text, 'text/plain', mtime
    end

    def send_page(cgi, content, type, mtime)
      header = {'status' => '200 OK',
                'type' => type,
                'charset' => @config.charset,
                'Pragma' => 'no-cache',
                'Cache-Control' => 'no-cache',
                'Content-Length' => content.length.to_s}
      header['Last-Modified'] = CGI.rfc1123_date(mtime) if mtime
      print cgi.header(header)
      print content unless cgi.request_method.to_s.upcase == 'HEAD'
      $stdout.flush
    end

    def send_error(cgi, err, debugp)
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

      print cgi.header 'status' => '200 OK',
                       'type' => 'text/html',
                       'charset' => 'us-ascii',
                       'Content-Length' => html.length
      print html unless cgi.request_method.to_s.upcase == 'HEAD'
    end

  end

end   # module BitChannel
