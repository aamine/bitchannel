#!/usr/bin/ruby
# $Id$

env = Object.new
env.instance_eval(File.read("#{File.dirname(__FILE__)}/bitchannelrc").untaint)
config, repo = env.initialize_environment
require 'bitchannel/handler'
require 'fcgi'
BitChannel::Handler.fcgi_main config, repo
