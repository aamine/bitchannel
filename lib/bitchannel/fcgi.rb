#
# $Id$
#
# Copyright (C) 2003,2004 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'bitchannel/cgi'
require 'fcgi'

module BitChannel

  class FCGI < CGI
    def FCGI.each_request
      Signal.trap(:PIPE, 'IGNORE')
      got_sigusr1 = false
      Signal.trap(:USR1) { got_sigusr1 = true }
      ::FCGI.each do |req|
        yield req.env, req.in, req.out
        req.finish
        raise SignalException, 'SIGUSR1' if got_sigusr1
      end
    ensure
      Signal.trap(:USR1, 'DEFAULT')
      Signal.trap(:PIPE, 'DEFAULT')
    end
  end

end
