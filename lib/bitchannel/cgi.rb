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
    def CGI.main(config, repo)
      new({}, config, repo).start
    end

    def do_GET(req, res)
      conf, repo = *@options
      Handler.new(conf, repo).service Request.new(req, conf, false), res
    end

    alias do_POST do_GET
  end

end
