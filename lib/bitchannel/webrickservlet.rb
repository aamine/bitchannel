#
# $Id$
#
# Copyright (C) 2003-2006 Minero Aoki
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
      wiki, = *@options
      wiki.session(guess_cgi_url(req)) {
        bcres = Handler.new(wiki).handle(Request.new(req, wiki.locale, true))
        bcres.update_for res
      }
    end

    alias do_POST do_GET

    private

    def guess_cgi_url(req)
      File.basename(req.path)
    end
  end

end
