#!/usr/bin/ruby
# $Id$

load './bitchannelrc'
$BitChannelContext ||= nil
unless $BitChannelContext
  setup_environment
  $BitChannelContext = bitchannel_context()
end
require 'bitchannel/cgi'
BitChannel::CGI.main $BitChannelContext
