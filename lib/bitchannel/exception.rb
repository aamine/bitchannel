#
# $Id$
#
# Copyright (C) 2003 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.
#

module Wikitik
  class WikitikError < StandardError; end
  class ConfigError < WikitikError; end
  class ResourceError < WikitikError; end
  class UnknownRCSLogFormat < WikitikError; end

  class CommandFailed < WikitikError
    def initialize(msg, status)
      @status = status
    end

    def precise_message
      @status.inspect
    end
  end

  class EditConflict < WikitikError
    def initialize(msg, merged)
      super msg
      @merged = merged
    end

    attr_reader :merged
  end
end
