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

    def extract_links(str)
      []
    end

    def compile(str, page_name)
      if /\A\#@@@meta/ =~ str
      then meta(str, page_name)
      else asis(str)
      end
    end

    private

    def meta(str, page_name)
      @repository.instance_eval { @wc_read }.chdir {
        return Object.new.instance_eval(str, "(meta:#{page_name})")
      }
    end

    def asis(str)
      buf = "<pre>\n"
      buf << escape_html(str)
      buf << "</pre>\n"
      buf
    end

  end

end   # module BitChannel
