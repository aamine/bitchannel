#!/usr/bin/ruby
# $Id$

load "#{File.dirname(__FILE__)}/bitchannelrc"
config, repo = initialize_environment()
BitChannel.cgi_main config, repo
