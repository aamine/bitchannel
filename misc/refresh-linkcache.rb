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
  require 'bitchannel/tohtml'

  wiki = bitchannel_context()
  repo = wiki._repository
  cache = repo.link_cache
  cache.clear
  c = BitChannel::ToHTML.new(wiki._config, repo)
  repo.page_names.each do |name|
    cache.update_cache_for name, c.extract_links(repo[name])
  end
end

main
