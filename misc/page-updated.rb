#!/usr/bin/env ruby
#
# $Id$
#

def main
  name = ARGV[0]

  load './bitchannelrc'
  setup_environment
  wiki = bitchannel_context()
  begin
    wiki._repository.updated_externally(name)
  rescue BitChannel::PageNotFound => err
    $stderr.puts err.message
    exit 1
  end
end

main
