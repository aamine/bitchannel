#!/usr/bin/env ruby
#
# index.rb
#

load "#{File.dirname(__FILE__)}/config"
$LOAD_PATH.unshift @libdir

require 'alphawiki'

def main
  config = AlphaWiki::Config.new(self)
  cmd, page, = *ARGV
  case cmd
  when 'view'
    print AlphaWiki::View.new(config, page).html
  when 'edit'
    print AlphaWiki::Edit.new(config, page).html
  else
    print AlphaWiki::View.new(config, AlphaWiki::INDEX_PAGE).html
  end
end

main
