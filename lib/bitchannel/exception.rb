#
# $Id$
#
# Copyright (C) 2003 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.
#

module AlphaWiki
  class AlphaWikiError < StandardError; end

  class CommandFailed < AlphaWikiError
    def initialize(msg, status)
      @status = status
    end

    def precise_message
      @status.inspect
    end
  end

  class EditConflict < AlphaWikiError
    def initialize(msg, merged)
      super msg
      @merged = merged
    end

    attr_reader :merged
  end

  class UnknownRCSLogFormat < AlphaWikiError; end
end
