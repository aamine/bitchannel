#
# $Id$
#
# Copyright (C) 2003,2004 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

module BitChannel
  class BitChannelError < StandardError; end
  class ConfigError < BitChannelError; end
  class ResourceError < BitChannelError; end
  class UnknownRCSLogFormat < BitChannelError; end
  class WrongQuery < BitChannelError; end
  class WrongPageName < BitChannelError; end

  class CommandFailed < BitChannelError
    def initialize(msg, status)
      super msg
      @status = status
    end

    def precise_message
      @status.inspect
    end
  end

  class EditConflict < BitChannelError
    def initialize(msg, merged)
      super msg
      @merged = merged
    end

    attr_reader :merged
  end
end
