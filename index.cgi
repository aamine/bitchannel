#!/usr/bin/ruby
# $Id$

rc = File.read("#{File.dirname(__FILE__)}/bitchannelrc".untaint).untaint
env = Object.new
env.instance_eval(rc, 'bitchannelrc')
config, repo = env.initialize_environment
require 'bitchannel/cgi'
BitChannel::CGI.main config, repo
