#!/usr/bin/env ruby
#
# $Id$
#

require 'getopts'

def usage(status)
  (status == 0 ? $stdout : $stderr).print(<<EOS)
Usage: #{File.basename($0)} [file file...] > output.html
EOS
  exit status
end

def main
  load './wikitikrc'
  ok = getopts(nil, 'help')
  usage(0) if $OPT_help
  usage(1) unless ok
  config, repo = initialize_environment()
  c = Wikitik::ToHTML.new(config, repo)
  ARGV.each do |page_name|
    puts c.compile(repo[page_name], page_name)
  end
end

main
