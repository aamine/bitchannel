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

  class Locale_ja < Locale

    def initialize(name, encoding)
      super()
      @name = name
      @encoding = encoding
      rc = rc_table()
      rc[:save_without_name] = _('Text saved without page name; make sure.')
      rc[:edit_conflicted] = _('Edit conflicted; make sure.')
    end

    attr_reader :name
    attr_reader :encoding
    alias mime_charset encoding
    alias charset encoding

    def xml_lang
      'ja'
    end

    begin
      begin
        require 'uconv'

        U8toLOCAL = {
          'euc-jp'    => :u8toeuc,
          'shift_jis' => :u8tosjis
        }

        def to_local(text)
          method = U8toLOCAL[@encoding]  or return to_local_NKF(text)
          Uconv.__send__(method, text)
        rescue Uconv::Error
          to_local_NKF(text)
        end

        LOCALtoU8 = {
          'euc-jp'    => :euctou8,
          'shift_jis' => :sjistou8
        }

        def utf8_enabled?
          LOCALtoU8[@encoding] ? true : false
        end

        def to_utf8(text)
          method = LOCALtoU8[@encoding]  or return text
          Uconv.__send__(method, text)
        end
      rescue LoadError
        require 'iconv'

        check = lambda {|code|
          begin
            Iconv.conv(code, 'UTF-8', 'test string')
            true
          rescue Iconv::InvalidEncoding
            false
          end
        }

        ICONV_NAME = {
          'euc-jp'    => %w(eucJP euc-jp EUC-JP).detect {|c| check[c] },
          'shift_jis' => %w(SJIS shift_jis Shift_JIS).detect {|c| check[c] }
        }

        def to_local(text)
          dest = ICONV_NAME[@encoding]  or return to_local_NKF(text)
          Iconv.conv(dest, 'UTF-8', text)
        rescue Iconv::Failure
          to_local_NKF(text)
        end

        def utf8_enabled?
          ICONV_NAME[@encoding] ? true : false
        end

        def to_utf8(text)
          src = ICONV_NAME[@encoding]  or return text
          Iconv.conv('UTF-8', src, text)
        end
      end
    rescue LoadError
      def to_local(text)
        to_local_NKF(text)
      end

      def utf8_enabled?
        false
      end
    end

    require 'nkf'

    MIME_CHARSET_TO_NKF = {
      'euc-jp'    => '-e -m0 -X',
      'shift_jis' => '-s -m0 -x',
      'iso-2022-jp' => '-j -m0 -x'
    }

    def to_local_NKF(text)
      flags = MIME_CHARSET_TO_NKF[@encoding] or return text
      NKF.nkf(flags, text)
    end

    alias _ to_local

    Z_SPACE = "\241\241"   # zen-kaku space

    def split_words(str)
      str.sub(/\A[\s#{Z_SPACE}]+/oe, '').sub(/[\s#{Z_SPACE}]+\z/oe, '')\
          .split(/[\s#{Z_SPACE}]+/oe)
    end

  end

  loc = Locale_ja.new('ja_JP.eucJP', 'euc-jp')
  Locale.declare_locale 'ja', loc
  Locale.declare_locale 'ja_JP', loc
  Locale.declare_locale 'ja_JP.eucJP', loc

  loc = Locale_ja.new('ja_JP.iso2022jp', 'iso-2022-jp')
  Locale.declare_locale 'ja_JP.iso2022jp', loc

end
