#!/usr/bin/env ruby
#
# index.rb
#

load "#{File.dirname(__FILE__)}/config"
$LOAD_PATH.unshift @libdir

require 'alphawiki'

def main
  config = AlphaWiki::Config.new(self)
  page = ARGV[0]
  print AlphaWiki::View.new(config, page).html
end

main
