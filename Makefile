#
# bitchannel Makefile
#

version = 0.1.0
datadir = $(HOME)/share
ardir   = $(HOME)/var/archive/tmail

default: all

all:
	@echo "no task"

dist:
	rm -rf tmp
	mkdir tmp
	cd tmp; cvs -Q export -r`echo V$(version) | tr . -` -d bitchannel-$(version) bitchannel
	cp $(datadir)/LGPL tmp/tmail-$(version)/COPYING
	cd tmp; tar czf $(ardir)/bitchannel-$(version).tar.gz bitchannel-$(version)
	rm -rf tmp

.PHONY: default all dist
