#
# $Id$
#
# Copyright (c) 2003-2005 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

module BitChannel
  class Locale_en < Locale
    def initialize
      super
      rc = rc_table()
      rc[:save_without_name] = 'Text saved without page name; make sure.'
      rc[:edit_conflicted] = 'Edit conflicted; make sure.'
    end

    def name
      'en_US.us-ascii'
    end

    def charset
      'us-ascii'
    end

    def xml_lang
      'en'
    end

    def to_local(str)
      str
    end

    def to_utf8(str)
      str
    end

    def split_words(str)
      str.strip.split
    end

    def utf8_enabled?
      true
    end
  end

  loc = Locale_en.new
  Locale.declare_locale 'C', loc
  Locale.declare_locale 'en', loc
  Locale.declare_locale 'en_US.us-ascii', loc
end
