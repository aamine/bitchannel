#!/usr/bin/ruby
# $Id$

load "#{File.dirname(__FILE__)}/bitchannelrc"
config, repo = initialize_environment()
require 'bitchannel/handler'
BitChannel.cgi_main config, repo
