#!/usr/bin/ruby
# $Id$
#
# BitChannel entry point for FastCGI environment.
#

load './bitchannelrc'
setup_environment
require 'bitchannel/fcgi'
BitChannel::FCGI.main bitchannel_context()
