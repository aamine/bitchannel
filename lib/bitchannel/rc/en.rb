#
# $Id$
#
# Copyright (C) 2003 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'bitchannel/exception'

module BitChannel
  rc = Hash.new {|h,k| raise ResourceError, "unknown resource key: #{k}" }
  rc[:save_without_name] = 'Text saved without page name; make sure.'
  rc[:edit_conflicted] = 'Edit conflicted; make sure.'
  @resources['en'] = rc
end
