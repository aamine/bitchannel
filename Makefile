#
# bitchannel Makefile
#

version = 0.3.1
datadir = $(HOME)/share
ardir   = $(HOME)/var/archive

default: rev

.PHONY: default rev dist

rev:
	echo '<p class="systeminfo">system revision' `cvs stat ChangeLog | awk '/Repository revision:/{print $$3}'`"</p>" > template/systeminfo.rhtml
	cvs ci -m 'update revision' template/systeminfo.rhtml

dist:
	rm -rf tmp
	mkdir tmp
	cd tmp; cvs -Q export -r`echo V$(version) | tr . -` -d bitchannel-$(version) bitchannel
	cp $(datadir)/LGPL tmp/bitchannel-$(version)/COPYING
	cd tmp; tar czf $(ardir)/bitchannel/bitchannel-$(version).tar.gz bitchannel-$(version)
	rm -rf tmp
