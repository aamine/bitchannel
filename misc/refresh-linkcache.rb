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
  config, repo = initialize_environment()
  cache = repo.link_cache
  cache.clear
  c = BitChannel::ToHTML.new(config, repo)
  repo.entries.each do |page_name|
    cache.update_cache_for page_name, c.extract_links(repo[page_name])
  end
end

main
