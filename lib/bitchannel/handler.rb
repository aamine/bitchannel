#
# $Id$
#
# Copyright (C) 2003 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.
#

require 'wikitik/textutils'
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

module Wikitik

  def Wikitik.cgi_main(repo, config)
    Handler.new(repo, config).handle_request(CGI.new)
  end

  #
  # CGI request handler class.
  # This object interprets a CGI request to the specific task.
  #
  class Handler

    include TextUtils

    def initialize(repo, config)
      @repository = repo
      @config = config
    end

    def handle_request(cgi)
      begin
        wiki_main cgi
      rescue Exception => err
        print "Content-Type: text/plain\r\n"
        print "Connection: close\r\n"
        print "\r\n"
        unless cgi.request_method.to_s.upcase == 'HEAD'
          puts "#{err.message} (#{err.class})"
          if true  #$DEBUG
            puts err.precise_message if err.respond_to?(:precise_message)
            err.backtrace.each do |i|
              puts i
            end
          end
        end
      end
    end

    private

    def wiki_main(cgi)
      case cgi.get_param('cmd').to_s.downcase
      when 'view'
        page_name = (cgi.get_param('name') || @config.index_page_name)
        rev = cgi.get_rev_param('rev')
        if rev
          page = ViewRevPage.new(@config, @repository, page_name, rev)
          send cgi, page.html, page.last_modified
        else
          view cgi, page_name
        end
      when 'edit'
        page_name = cgi.get_param('name')
        unless page_name
          view cgi, @config.index_page_name
          return
        end
        edit cgi, page_name
      when 'save'
        page_name = cgi.get_param('name')
        unless page_name
          send cgi, EditPage.new(@config, @repository,
                                 @config.tmp_page_name, nil,
                                 cgi.get_param('text').to_s,
                                 gettext(:save_without_name)).html
          return
        end
        begin
          text = cgi.get_param('text').to_s.gsub(/\r\n|\n|\r/, "\r\n")
          @repository.checkin page_name,
                              cgi.get_rev_param('origrev'),
                              text
          thanks cgi, page_name
        rescue EditConflict => err
          send cgi, EditPage.new(@config, @repository,
                                 page_name, nil,
                                 merged, gettext(:edit_conflicted)).html
        end
      when 'diff'
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
        send cgi, DiffPage.new(@config, @repository, page_name, rev1, rev2).html
      when 'history'
        page_name = cgi.get_param('name')
        if not page_name or not @repository.exist?(page_name)
          view cgi, @config.index_page_name
          return
        end
        send cgi, HistoryPage.new(@config, @repository, page_name).html
      when 'src'
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
      when 'list'
        send cgi, ListPage.new(@config, @repository).html
      when 'recent'
        send cgi, RecentPage.new(@config, @repository).html
      when 'search'
        begin
          regs = setup_query(cgi.get_param('q'))
          send cgi, SearchResultPage.new(@config, @repository, cgi.get_param('q'), regs).html
        rescue WrongQuery => err
          send cgi, SearchErrorPage.new(@config, @repository, cgi.get_param('q'), err).html
        end
      else
        view cgi, (cgi.get_param('name') || @config.index_page_name)
      end
    end

    def view(cgi, page_name)
raise ArgumentError, "view page=nil" unless page_name
      unless @repository.exist?(page_name)
        edit cgi, page_name
        return
      end
      page = ViewPage.new(@config, @repository, page_name)
      send cgi, page.html, page.last_modified
    end

    def edit(cgi, page_name)
      send cgi, EditPage.new(@config, @repository, page_name).html
    end

    def thanks(cgi, page_name)
      send cgi, <<-ThanksPage
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

    def send(cgi, html, mtime = nil)
      header = {'status' => '200 OK',
                'type' => 'text/html',
                'charset' => @config.charset,
                'Pragma' => 'no-cache',
                'Cache-Control' => 'no-cache',
                'Content-Length' => html.length.to_s}
      header['Last-Modified'] = CGI.rfc1123_date(mtime) if mtime
      print cgi.header(header)
      print html unless cgi.request_method.to_s.upcase == 'HEAD'
      $stdout.flush
    end

    def send_text(cgi, text, mtime = nil)
      header = {'status' => '200 OK',
                'type' => 'text/plain',
                'charset' => @config.charset,
                'Pragma' => 'no-cache',
                'Cache-Control' => 'no-cache',
                'Content-Length' => text.length.to_s}
      header['Last-Modified'] = CGI.rfc1123_date(mtime) if mtime
      print cgi.header(header)
      print text unless cgi.request_method.to_s.upcase == 'HEAD'
      $stdout.flush
    end

  end

end   # module Wikitik
