#!/usr/bin/ruby

load "#{File.dirname(__FILE__)}/wikitikrc"
config, repo = initialize_environment()
Wikitik.cgi_main config, repo
