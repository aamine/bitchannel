#!/usr/bin/env ruby
#
# index.rb
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
  config = AlphaWiki::Config.new(self)
  cgi = CGI.new
  case cgi.get_param('cmd')
  when 'view'
    print AlphaWiki::ViewPage.new(config, cgi.get_param('name')).html
  when 'edit'
    print AlphaWiki::EditPage.new(config, cgi.get_param('name')).html
  when 'save'
    print AlphaWiki::EditPage.new(config, cgi.get_param('name')).html
  else
    print AlphaWiki::ViewPage.new(config, config.index_page_name).html
  end
end

main
