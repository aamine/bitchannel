#!/usr/bin/env ruby
#
# $Id$
#

require 'getopts'
require 'fileutils'

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
  FileUtils.rm_rf config.link_cachedir
  FileUtils.rm_rf config.revlink_cachedir
  linkcache = BitChannel::LinkCache.new(config.link_cachedir,
                                        config.revlink_cachedir)
  c = BitChannel::ToHTML.new(config, repo)
  repo.entries.each do |page_name|
    linkcache.update_cache_for page_name, c.extract_links(repo[page_name])
  end
end

main
