#!/usr/bin/ruby
# $Id$
#
# BitChannel entry point for (pure) CGI environment.
#
# !!!! WARNING !!!!
# Never use this file for multisession environment e.g. mod_ruby, esehttpd.
# Use index.rbx instead.
#

load './bitchannelrc'
setup_environment
require 'bitchannel/cgi'
BitChannel::CGI.main bitchannel_context()
