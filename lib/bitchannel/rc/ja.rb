#
# $Id$
#
# Copyright (C) 2003 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.
#

require 'wikitik/exception'

module Wikitik
  Resource_ja = Hash.new {|h,k| raise ResourceError, "unknown resource key: #{k}" }
  @resource = Resource_ja
  Resource_ja[:save_without_name] = 'Text saved without page name; make sure.'
  Resource_ja[:conflict] = 'Edit conflicted; make sure.'
  Resource_ja[:last_modified] = 'Last Modified'
end
