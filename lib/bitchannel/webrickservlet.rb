#
# $Id$
#
# Copyright (C) 2003,2004 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'webrick/httpservlet'
require 'bitchannel/handler'

module BitChannel

  class WebrickServlet < WEBrick::HTTPServlet::AbstractServlet
    @@config = nil
    @@repository = nil

    def WebrickServlet.set_environment(config, repo)
      @@config = config
      @@repository = repo
    end

    def do_GET(req, res)
      conf = @@config.dup
      conf.cgi_url = File.dirname(req.path)
      res0 = Handler.new(conf, @@repository).handle(WebrickRequestWrapper.new(req))
      res['content-type'] = res0.content_type
      res['last-modified'] = res0.last_modified if res0.last_modified
      if res0.no_cache?
        res['cache-controle'] = 'no-cache'
        res['pragma'] = 'no-cache'
      end
      res.body = res0.body
      @@repository.clear_per_request_cache
    end

    alias do_POST do_GET
  end

  class WebrickRequestWrapper
    def initialize(req)
      @request = req
    end

    def get_param(name)
      if name == 'name' and not @request.query['name']
        n = @request.path.split('/').last
        return nil unless n
        return nil if n.empty?
        n.sub(/\.html\z/, '')
      else
        data = @request.query[name]
        return nil unless data
        return nil if data.empty?
        data.to_s
      end
    end

    def get_rev_param(name)
      rev = get_param(name).to_i
      return nil if rev < 1
      rev
    end
  end

end
