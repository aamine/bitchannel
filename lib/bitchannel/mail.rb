#
# $Id$
#
# Copyright (C) 2003-2006 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'time'
require 'stringio'

module BitChannel

  class Mail

    def initialize
      @date = Time.now
      @from = nil
      @to = []
      @subject = nil
      @mime_version = '1.0'
      @content_type = 'text/plain'
      @body = nil
    end

    attr_accessor :date

    attr_accessor :from

    attr_reader :to

    def to=(tos)
      @to = [tos].flatten
    end

    attr_accessor :subject

    attr_accessor :mime_version

    def content_type
      @content_type.split(';', 2).first
    end

    def charset
      c = @content_type.split(';', 2).last or return nil
      c.split('=', 2).last.gsub(/"/, '')
    end

    def charset=(c)
      @content_type = "text/plain; charset=#{c}"
    end

    attr_accessor :body

    def encoded
      check_fields
      buf = ''
      buf << "From: #{@from}\r\n"
      buf << "To: #{@to.join(', ')}\r\n"
      buf << "Date: #{@date.rfc2822}\r\n"
      buf << "Subject: #{@subject}\r\n"
      buf << "Mime-Version: #{@mime_version}\r\n"
      buf << "Content-Type: #{@content_type}\r\n"
      buf << "\r\n"
      buf << @body
      buf
    end

    alias to_s encoded

    private

    def check_fields
      raise ArgumentError, "no Date:" unless @date
      raise ArgumentError, "no From:" unless @from
      raise ArgumentError, "no To:" if @to.empty?
      raise ArgumentError, "no Subject:" unless @subject
      raise ArgumentError, "no body" unless @body
    end
  
  end

end
