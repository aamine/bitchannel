#!/usr/bin/ruby
# $Id$

rc = File.read("#{File.dirname(__FILE__)}/bitchannelrc").untaint
env = Object.new
env.instance_eval(rc, 'bitchannelrc')
config, repo = env.initialize_environment
require 'bitchannel/handler'
require 'fcgi'
BitChannel::Handler.fcgi_main config, repo
