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
$LOAD_PATH.unshift @libdir

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
    print "#{err.message} (#{err.class})\r\n" unless cgi.request_method.upcase == 'HEAD'
  end
end

def wiki_main(config, cgi)
  config = AlphaWiki::Config.new(self)
  repo = AlphaWiki::Repository.new(@cvs_path, @cvswc_read, @cvswc_write)
  case cgi.get_param('cmd').to_s.downcase
  when 'view'
    send cgi, AlphaWiki::ViewPage.new(config, repo, cgi.get_param('name')).html
  when 'edit'
    send cgi, AlphaWiki::EditPage.new(config, repo, cgi.get_param('name')).html
  when 'save'
    begin
      repo.checkin cgi.get_param('name'),
                   cgi.get_param('origrev'),
                   cgi.get_param('text')
      send cgi, AlphaWiki::ViewPage.new(config, repo, cgi.get_param('name')).html
    rescue AlphaWiki::EditConflict => err
      send cgi, AlphaWiki::ConflictedPage.new(config, repo, cgi.get_param('name'), err.merged).html
    end
  else
    send cgi, AlphaWiki::ViewPage.new(config, repo, config.index_page_name).html
  end
end

def send(cgi, html)
  cgi.header('status' => '200 OK',
             'type' => 'text/html', 'charset' => @charset,
             'Content-Length' => html.length.to_s)
  print html unless cgi.request_method.upcase == 'HEAD'
end

main
