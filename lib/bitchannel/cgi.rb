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
require 'bitchannel/webrick_cgi'

module BitChannel
  class CGI < WEBrick::CGI
    def CGI.main(wiki)
      super({}, wiki)
    end

    def init_application(wiki)
      @wiki = wiki
    end

    def do_GET(req, res)
      bcres = Handler.new(@wiki).handle(Request.new(req, @wiki.locale, false))
      bcres.update_for res
    end

    alias do_POST do_GET
  end
end
