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
  load './wikitikrc'
  ok = getopts(nil, 'help')
  usage(0) if $OPT_help
  usage(1) unless ok
  config, repo = initialize_environment()
  FileUtils.rm_rf config.link_cachedir
  FileUtils.rm_rf config.revlink_cachedir
  linkcache = Wikitik::LinkCachen.new(config.link_cachedir,
                                      config.revlink_cachedir)
  c = Wikitik::ToHTML.new(config, repo)
  repo.entries.each do |page_name|
    linkcache.update_cache_for page_name, c.extract_links(repo[page_name])
  end
end

main
