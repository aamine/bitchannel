#!/usr/bin/ruby
#
# Wikitik Config File
#

$KCODE = 'EUC'

cgidir = File.dirname(File.expand_path(__FILE__))

$:.unshift "#{cgidir}/lib"
require 'wikitik'
require 'wikitik/rc/ja'

repo = Wikitik::Repository.new(
  :cmd_path  => '/usr/bin/cvs',
  # :cvsroot => '/home/aamine/var/cvs/test',
  :wc_read   => "#{cgidir}/wc.read",
  :wc_write  => "#{cgidir}/wc.write"
)
config = Wikitik::Config.new(
  :templatedir => "#{cgidir}/template",
  :charset => 'euc-jp',
  :css_url => 'default.css',
  :cgi_url => 'index.rb'
)
Wikitik.cgi_main repo, config
