#!/usr/bin/env ruby
#
# $Id$
#

require 'optparse'

def main
  parser = OptionParser.new
  parser.on('--help') {
    puts parser.help
    exit 0
  }
  begin
    parser.parse!
  rescue OptionParser::ParseError => err
    $stderr.puts err.message
    $stderr.puts parser.help
    exit 1
  end

  load './bitchannelrc'
  setup_environment
  wiki = bitchannel_context()
  wiki._repository.link_cache.clear
  wiki._repository.revlink_cache.clear
  revlinks = {}
  wiki._repository.pages.each do |page|
    page.links
    page.links.each do |dest|
      (revlinks[dest] ||= []).push page.name
    end
  end
  revlinks.each do |name, revlinks|
    wiki._repository.revlink_cache[name] = revlinks
  end
end

main
