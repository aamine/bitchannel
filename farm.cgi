#!/usr/bin/ruby

load './farmrc'
setup_environment
require 'bitchannel/farm'
require 'bitchannel/cgi'
BitChannel::FarmCGI.main farm_context()
