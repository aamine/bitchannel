#
# $Id$
#
# Copyright (C) 2003,2004 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'bitchannel/webrick_cgi'
require 'fcgi'

module WEBrick
  class CGI
    def CGI.each_fcgi_request
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

    class << CGI
      remove_method :each_request
    end
    def CGI.each_request(&block)
      if FCGI.is_cgi?
        each_cgi_request(&block)
      else
        each_fcgi_request(&block)
      end
    end
  end
end
