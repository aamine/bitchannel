#!/usr/bin/ruby
# $Id$

env = Object.new
env.instance_eval(File.read("#{File.dirname(__FILE__)}/bitchannelrc".untaint).untaint)
config, repo = env.initialize_environment
require 'bitchannel/handler'
BitChannel::Handler.cgi_main config, repo
