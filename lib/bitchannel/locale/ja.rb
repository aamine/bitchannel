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
  class Locale_ja < Locale
    def initialize
      super
      rc = rc_table()
      rc[:save_without_name] = 'Text saved without page name; make sure.'
      rc[:edit_conflicted] = 'Edit conflicted; make sure.'
    end

    def name
      'ja_JP.eucJP'
    end

    def charset
      'euc-jp'
    end
  end

  loc = Locale_ja.new
  Locale.declare_locale 'ja', loc
  Locale.declare_locale 'ja_JP', loc
  Locale.declare_locale 'ja_JP.eucJP', loc
end
