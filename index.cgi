#!/usr/bin/ruby
# $Id$

rc = File.read("#{File.dirname(__FILE__)}/bitchannelrc".untaint).untaint
env = Object.new
env.instance_eval(rc, 'bitchannelrc')

# ugly kluge for mod_ruby
$BitChannelInitialized ||= false
unless $BitChannelInitialized
  env.setup_environment
  $BitChannelInitialized = true
end

require 'bitchannel/cgi'
BitChannel::CGI.main(*env.bitchannel_context)
