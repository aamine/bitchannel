#!/usr/bin/env ruby
#
# $Id$
#

require 'getopts'

def usage(status)
  (status == 0 ? $stdout : $stderr).print(<<EOS)
Usage: #{File.basename($0)}
EOS
  exit status
end

def main
  ok = getopts(nil, 'help')
  usage(0) if $OPT_help
  usage(1) unless ok

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
