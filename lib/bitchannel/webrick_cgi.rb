#
# $Id$
#
# Copyright (C) 2003,2004 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'webrick/cgi'

module WEBrick
  class CGI
    def CGI.main(conf, *context)
      app = new(conf)
      app.init_application(*context)
      app.run
    end

    def CGI.each_cgi_request
      yield ENV, $stdin, $stdout
    end

    def CGI.each_request(&block)
      each_cgi_request(&block)
    end

    def run
      CGI.each_request do |env, stdin, stdout|
        start env, stdin, stdout
      end
    end
  end
end
