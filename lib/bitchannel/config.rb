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

  FRONT_PAGE_NAME = 'FrontPage'
  HELP_PAGE_NAME = 'HelpPage'
  TMP_PAGE_NAME = 'tmp'

  class Config
    def initialize(args)
      args = args.dup
      def args.getopt(name)
        raise ConfigError, "Config Error: not set: config.#{name}" \
            unless key?(name)
        delete(name).untaint
      end
      def args.fetchopt(name, default)
        return default unless key?(name)
        delete(name).untaint
      end

      @templatedir = args.getopt(:templatedir)
      @charset     = args.getopt(:charset)
      @css_url     = args.getopt(:css_url)
      @html_url_p  = args.getopt(:use_html_url)
      @site_name   = args.fetchopt(:site_name, nil)
      @logo_url    = args.fetchopt(:logo_url, nil)
      args.each do |key, val|
        raise ConfigError, "Config Error: unknown key: config.#{key}"
      end

      @cgi_url = nil
    end

    attr_reader :templatedir
    attr_reader :charset
    attr_reader :css_url
    attr_reader :logo_url

    def html_url?
      @html_url_p
    end

    attr_writer :cgi_url

    def cgi_url
      return @cgi_url if @cgi_url
      return ENV['SCRIPT_NAME'] if ENV['SCRIPT_NAME']
      return File.basename(::Apache.request.filename) if defined?(::Apache)
      return File.basename($0) if $0
      raise "cannot get cgi url; given up"
    end

    def site_name
      @site_name || FRONT_PAGE_NAME
    end
  end

end
