#!/usr/bin/ruby
# $Id$

$BitChannelFarm ||= false
unless $BitChannelContext
  load './farmrc'
  setup_environment
  require 'bitchannel/farm'
  require 'bitchannel/cgi'
  $BitChannelContext = farm_context()
end
BitChannel::FarmCGI.main $BitChannelContext
