#
# $Id$
#
# Copyright (C) 2003 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.
#

require 'alphawiki/exception'

module AlphaWiki
  Resource_en = Hash.new {|h,k| raise ResourceError, "unknown resource key: #{k}" }
  Resource_en[:save_without_name] = 'Text saved without page name; make sure.'
  Resource_en[:conflict] = 'Edit conflicted; make sure.'
  @resource = Resource_en
end
