#!/usr/bin/ruby
# $Id$

load './bitchannelrc'
setup_environment
require 'bitchannel/fcgi'
BitChannel::FCGI.main(*bitchannel_context())
