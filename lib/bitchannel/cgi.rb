#
# $Id$
#
# Copyright (C) 2003,2004 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'bitchannel/handler'
require 'webrick/cgi'

module BitChannel

  class CGI < WEBrick::CGI
    def CGI.main(*context)
      run new({}, *context)
    end

    def CGI.run(app)
      each_request do |env, stdin, stdout|
        app.start env, stdin, stdout
      end
    end

    def CGI.each_request
      yield ENV, $stdin, $stdout
    end

    def do_GET(req, res)
      h = Handler.new(*@options)
      h.handle(Request.new(req, h.config, false)).update_for res
    end

    alias do_POST do_GET
  end

end
