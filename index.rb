#!/usr/bin/env ruby
#
# $Id$
#
# Copyright (C) 2003 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.
#

load "#{File.dirname(__FILE__)}/config"
$LOAD_PATH.unshift @libdir if @libdir

require 'alphawiki'
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

def main
  cgi = CGI.new
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

def wiki_main(cgi)
  repo = AlphaWiki::Repository.new(@cvs_path, @cvswc_read, @cvswc_write)
  config = AlphaWiki::Config.new(self)
  case cgi.get_param('cmd').to_s.downcase
  when 'view'
    view repo, config, cgi, cgi.get_param('name')
  when 'edit'
    edit repo, config, cgi, cgi.get_param('name')
  when 'save'
    page_name = cgi.get_param('name')
    unless page_name
      send cgi, AlphaWiki::EditPage.new(config, repo,
                                        config.tmp_page_name, nil,
                                        cgi.get_param('text').to_s,
                                        text(:save_without_name)).html
      return
    end
    origrev = cgi.get_param('origrev').to_i
    origrev = nil if origrev == 0
    begin
      repo.checkin page_name, origrev, (cgi.get_param('text') || "")
      view repo, config, cgi, page_name
    rescue AlphaWiki::EditConflict => err
      send cgi, AlphaWiki::EditPage.new(config, repo,
                                        page_name, nil,
                                        merged, text(:conflict)).html
    end
  when 'history'
    history repo, config, cgi, cgi.get_param('name')
  when 'list'
    send cgi, AlphaWiki::ListPage.new(config, repo).html
  when 'recent'
    send cgi, AlphaWiki::RecentPage.new(config, repo).html
  else
    view repo, config, cgi, cgi.get_param('name')
  end
end

def view(repo, config, cgi, page_name)
  page_name ||= config.index_page_name
  unless repo.exist?(page_name)
    edit repo, config, cgi, page_name
    return
  end
  send cgi,
       AlphaWiki::ViewPage.new(config, repo, page_name).html,
       repo.mtime(page_name)
end

def edit(repo, config, cgi, page_name)
  unless page_name
    view repo, config, cgi, config.index_page_name
    return
  end
  send cgi, AlphaWiki::EditPage.new(config, repo, page_name).html
end

def history(repo, config, cgi, page_name)
  if not page_name or not repo.exist?(page_name)
    view repo, config, cgi, config.index_page_name
    return
  end
  send cgi, AlphaWiki::HistoryPage.new(config, repo, page_name).html
end

def send(cgi, html, mtime = nil)
  header = {'status' => '200 OK',
            'type' => 'text/html', 'charset' => @charset,
            'Pragma' => 'no-cache',
            'Cache-Control' => 'no-cache',
            'Content-Length' => html.length.to_s}
  header['Last-Modified'] = CGI.rfc1123_date(mtime) if mtime
  print cgi.header(header)
  print html unless cgi.request_method.to_s.upcase == 'HEAD'
end

def text(key)
  AlphaWiki.gettext(key)
end

main
