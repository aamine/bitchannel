#!/usr/bin/ruby
# $Id$
#
# BitChannel entry point for multisession environment --
# mod_ruby or esehttpd embedded interpreter.
#

load './bitchannelrc'
$BitChannelContext ||= nil
unless $BitChannelContext
  setup_environment
  $BitChannelContext = bitchannel_context()
end
require 'bitchannel/cgi'
BitChannel::CGI.main $BitChannelContext
