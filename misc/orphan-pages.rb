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

  load './wikitikrc'
  config, repo = initialize_environment()
  repo.orphan_pages.each do |page_name|
    puts page_name
  end
end

main
