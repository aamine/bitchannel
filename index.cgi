#!/usr/bin/ruby
# $Id$

rc = File.read("#{File.dirname(__FILE__)}/bitchannelrc".untaint).untaint
env = Object.new
env.instance_eval(rc, 'bitchannelrc')
env.setup_environment
require 'bitchannel/cgi'
BitChannel::CGI.main(*env.bitchannel_context)
