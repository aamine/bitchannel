#
# $Id$
#
# Copyright (C) 2003 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.
#

require 'cgi'

class CGI
  def get_param(name)
    a = params()[name]
    return nil unless a
    return nil unless a[0]
    return nil if a[0].empty?
    a[0]
  end
end

module Wikitik

  def Wikitik.main(repo, config)
    Handler.new(repo, config).handle_request(CGI.new)
  end

  class Handler

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
        view cgi, cgi.get_param('name')
      when 'edit'
        edit cgi, cgi.get_param('name')
      when 'save'
        page_name = cgi.get_param('name')
        unless page_name
          send cgi, EditPage.new(@config, @repository,
                                 @config.tmp_page_name, nil,
                                 cgi.get_param('text').to_s,
                                 gettext(:save_without_name)).html
          return
        end
        origrev = cgi.get_param('origrev').to_i
        origrev = nil if origrev == 0
        begin
          @repository.checkin page_name, origrev, (cgi.get_param('text') || "")
          view cgi, page_name
        rescue EditConflict => err
          send cgi, EditPage.new(@config, @repository,
                                 page_name, nil,
                                 merged, gettext(:conflict)).html
        end
      when 'history'
        history cgi, cgi.get_param('name')
      when 'list'
        send cgi, ListPage.new(@config, @repository).html
      when 'recent'
        send cgi, RecentPage.new(@config, @repository).html
      else
        view cgi, cgi.get_param('name')
      end
    end

    def view(cgi, page_name)
      page_name ||= @config.index_page_name
      unless @repository.exist?(page_name)
        edit cgi, page_name
        return
      end
      rev = cgi.get_param('rev')
      if rev and rev.to_i > 0
        viewrev cgi, page_name, rev.to_i
        return
      end
      page = ViewPage.new(@config, @repository, page_name)
      send cgi, page.html, page.last_modified
    end

    def viewrev(cgi, page_name, rev)
      page = ViewRevPage.new(@config, @repository, page_name, rev)
      send cgi, page.html, page.last_modified
    end

    def edit(cgi, page_name)
      unless page_name
        view cgi, @config.index_page_name
        return
      end
      send cgi, EditPage.new(@config, @repository, page_name).html
    end

    def history(cgi, page_name)
      if not page_name or not @repository.exist?(page_name)
        view cgi, @config.index_page_name
        return
      end
      send cgi, HistoryPage.new(@config, @repository, page_name).html
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
    end

  end

end   # module Wikitik
