#
# $Id$
#
# Copyright (C) 2003-2006 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'bitchannel/handler'
require 'webrick/cgi'
require 'webrick/accesslog'

module WEBrick
  class CGI   # reopen
    def CGI.main(conf, *context)
      new(conf, *context).run
    end

    def CGI.each_request(&block)
      yield ENV, $stdin, $stdout
    end

    def run
      CGI.each_request do |env, stdin, stdout|
        start env, stdin, stdout
      end
    end
  end
end

module BitChannel
  class CGI < WEBrick::CGI
    def CGI.main(wiki, webrickconf = {})
      super(webrickconf, wiki)
    end

    def do_GET(req, res)
      wiki, = *@options
      wiki.session(guess_cgi_url(req)) {
        bcres = Handler.new(wiki).handle(Request.new(req, wiki.locale, false))
        bcres.update_for res
      }
    end

    alias do_POST do_GET

    private

    def guess_cgi_url(req)
      return req.path if req.path
      return req.script_name if req.script_name
      return File.basename(::Apache.request.filename) if defined?(::Apache)
      return File.basename($0) if $0
      raise "cannot get CGI url; give up"
    end
  end
end
