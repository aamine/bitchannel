#!/usr/bin/ruby
# $Id$
#
# !!!! WARNING !!!!
# Never use this file for multisession environment e.g. mod_ruby, esehttpd.
# Use index.rbx instead.
#

load './farmrc'
setup_environment
require 'bitchannel/farm'
require 'bitchannel/cgi'
BitChannel::FarmCGI.main farm_context()
