#
# $Id$
#
# Copyright (C) 2003,2004 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'bitchannel/config'
require 'bitchannel/mail'
require 'net/smtp'
require 'socket'

module BitChannel

  class SMTPNotifier

    def initialize(hash)
      UserConfig.parse(hash, 'smtpnotifier') {|conf|
        @host        = conf.get_required(:host)
        @port        = conf.get_optional(:port, Net::SMTP.default_port)
        @helo_domain = conf.get_optional(:helo, Socket.gethostname)
        @from        = conf.get_required(:from)
        @to          = [conf.get_required(:to)].flatten
        @subject     = conf.get_optional(:subject, default_subject_maker())
        @locale      = conf.get_required(:locale)
      }
    end

    def notify(diff)
      smtp = Net::SMTP.new(@host, @port)
      smtp.set_debug_output $stderr
      msg = message(mod, diff)
      smtp.start(@helo_domain) {
        smtp.send_message msg, @from, @to
      }
    end

    private

    def message(diff)
      m = Mail.new
      m.from = @from
      m.to = @to
      m.subject = @subject_maker.call(diff.module, diff.page_name, diff.rev2)
      m.charset = @locale.charset
      m.body = diff.diff
      m.encoded
    end

    def default_subject_maker
      lambda {|mod, page, rev|
        "BitChannel: #{mod ? mod+'/' : ''}#{page}:#{rev}"
      }
    end
  
  end


  class MailerNotifier

    def initialize(hash)
      UserConfig.parse(hash) {|conf|
        @format  = conf.get_required(:format)
        @from    = conf.get_required(:from)
        @to      = [conf.get_required(:to)].flatten
        @subject_maker = conf.get_optional(:subject, default_subject_maker())
        @locale = conf.get_required(:locale)
      }
    end

    def notify(diff)
      msg = message(diff)
      Kernel.open("| #{make_command(@format)}", 'w') {|f|
        f.write msg
      }
    end

    private

    def make_command
      fmt.sub(/%from/) {
        @from
      }.sub(/%to([\+\,])?/) {
        case $1
        when '+', nil
          @to.join(' ')
        when ','
          @to.join(',')
        end
      }
    end

    def message(diff)
      m = Mail.new
      m.from = @from
      m.to = @to
      m.subject = @subject_maker.call(diff.module, diff.page_name, diff.rev2)
      m.charset = @locale.charset
      m.body = diff.diff
      m.encoded
    end

    def default_subject_maker
      lambda {|mod, page, rev|
        "BitChannel: #{mod ? mod+'/' : ''}#{page}:#{rev}"
      }
    end
  
  end


  class CascadingNotifier

    def initialize(ns)
      @notifiers = ns.dup
    end

    def add(n)
      @notifiers.push n
    end

    def notify(diff)
      @notifiers.each do |n|
        n.notify diff
      end
    end
  
  end

end
