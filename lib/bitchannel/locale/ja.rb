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

    begin
      begin
        require 'uconv'

        MIME_CHARSET_TO_UCONV = {
          'euc-jp'    => :u8toeuc,
          'shift_jis' => :u8tosjis
        }

        def unify_encoding(text)
          method = MIME_CHARSET_TO_UCONV[charset()] or return text
          Uconv.__send__(method, text)
        rescue Uconv::Error
          unify_encoding_NKF(text, charset())
        end
      rescue LoadError
        require 'iconv'

        check = lambda {|code|
          begin
            Iconv.iconv(code, 'UTF-8', 'test string')
            true
          rescue Iconv::InvalidEncoding
            false
          end
        }

        MIME_CHARSET_TO_ICONV = {
          'euc-jp'    => %w(eucJP euc-jp EUC-JP).find {|c| check[c] },
          'shift_jis' => %w(SJIS shift_jis Shift_JIS).find {|c| check[c] }
        }

        def unify_encoding(text)
          dest = MIME_CHARSET_TO_ICONV[charset()] or return text
          Iconv.iconv(dest, 'UTF-8', text)
        rescue Iconv::Failure
          unify_encoding_NKF(text, charset())
        end
      end
    rescue LoadError
      def unify_encoding(text)
        unify_encoding_NKF(text)
      end
    end

    require 'nkf'

    MIME_CHARSET_TO_NKF = {
      'euc-jp'    => '-e -m0 -X',
      'shift_jis' => '-s -m0 -x'
    }

    def unify_encoding_NKF(text)
      flags = MIME_CHARSET_TO_NKF[charset()] or return text
      NKF.nkf(flags, text)
    end


    Z_SPACE = "\241\241"   # zen-kaku space

    def split_words(str)
      str.sub(/\A[\s#{Z_SPACE}]+/oe, '').sub(/[\s#{Z_SPACE}]+\z/oe, '')\
          .split(/[\s#{Z_SPACE}]+/oe)
    end

  end

  loc = Locale_ja.new
  Locale.declare_locale 'ja', loc
  Locale.declare_locale 'ja_JP', loc
  Locale.declare_locale 'ja_JP.eucJP', loc

end
