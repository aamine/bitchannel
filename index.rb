#!/usr/bin/env ruby
#
# index.rb
#

load "#{File.dirname(__FILE__)}/alphawiki.conf"
$LOAD_PATH.unshift @libdir

require 'alphawiki'

def main
  page = ARGV[0]
  print AlphaWiki::View.new(page).html
end

main
