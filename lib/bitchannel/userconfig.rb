#
# $Id$
#
# Copyright (C) 2003,2004 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'bitchannel/exception'

module BitChannel

  class UserConfig

    def UserConfig.parse(hash, category)
      conf = new(hash, category)
      yield conf
      conf.check_unknown_options
    end
      
    def initialize(hash, category)
      @config = hash.dup
      @config.each_value do |v|
        v.untaint
      end
      @category = category
      @refered = []
    end

    def get(key)
      @refered.push key
      return nil unless @config.key?(key)
      if block_given?
      then yield(@config[key])
      else @config[key]
      end
    end

    alias [] get

    def get_required(key)
      required! key
      get(key)
    end

    def ignore(key)
      @refered.push key
    end

    # Just 1 key must exist
    def required!(key)
      unless @config.key?(key)
        raise ConfigError, "Config Error: not set: #{@category}.#{key}"
      end
    end

    # Only 0 or 1 key from KEYS must exist
    def exclusive!(*keys)
      if keys.map {|k| @config.key?(k) }.select {|b| b }.size > 1
        raise ConfigError,
            keys.map {|k| "#{@category}.#{k}" }.join(' and ') + ' are exclusive'
      end
    end

    # Only 1 key from KEYS must exist
    def select!(*keys)
      exclusive! keys
      if keys.all? {|k| not @config.key?(k) }
        raise ConfigError,
            "at least 1 key required: " +
            keys.map {|k| "#{@category}.#{k}" }.join(', ')
      end
    end

    def check_unknown_options
      unknown = (@config.keys - @refered).uniq
      unless unknown.empty?
        raise ConfigError,
            'BitChannel Configuration Error: unknown keys: ' +
            unknown.map {|k| "#{@category}.#{k}" }.join(', ')
      end
    end

  end

end
