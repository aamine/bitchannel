#
# $Id$
#
# Copyright (C) 2003,2004 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'webrick/httpservlet/abstract'
require 'bitchannel/handler'

module BitChannel

  class WebrickServlet < WEBrick::HTTPServlet::AbstractServlet
    def do_GET(req, res)
      h = Handler.new(*@options)
      h.config.suggest_cgi_url File.dirname(req.path)
      h.handle(Request.new(req, h.config, true)).update_for res
    end

    alias do_POST do_GET
  end

end
