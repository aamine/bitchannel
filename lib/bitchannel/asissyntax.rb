#
# $Id$
#
# Copyright (C) 2003,2004 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'bitchannel/textutils'

module BitChannel

  class ASISSyntax

    include TextUtils

    def initialize(config, repo)
      @config = config
      @repository = repo
    end

    def compile(str, page_name)
      buf = "<pre>\n"
      buf << escape_html(str)
      buf << "</pre>\n"
      buf
    end

    def extract_links(str)
      []
    end

  end

end   # module BitChannel
