#!/usr/bin/ruby
# $Id$

load './farmrc'
setup_environment
require 'bitchannel/farm'
require 'bitchannel/fcgi'
BitChannel::FarmCGI.main farm_context()
