#!/usr/bin/ruby
# $Id$

load './bitchannelrc'

$BitChannelInitialized ||= false
unless $BitChannelInitialized
  setup_environment
  $BitChannelInitialized = true
end

require 'bitchannel/cgi'
BitChannel::CGI.main(*bitchannel_context())
