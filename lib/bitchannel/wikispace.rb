#
# $Id$
#
# Copyright (C) 2003,2004 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'bitchannel/page'
require 'bitchannel/textutils'
require 'bitchannel/syntax'
require 'bitchannel/threadlocalcache'

module BitChannel

  class WikiSpace

    include TextUtils

    def initialize(config, repo)
      @config = config
      @repository = repo
      @repository.syntax ||= Syntax.new(config, repo)
    end

    # misc command use only
    def _config
      @config
    end
    def _repository
      @repository
    end

    def session(guess_cgi_url)
      @config.cgi_url ||= guess_cgi_url
      raise 'CGI url could not fixed; give up' unless @config.cgi_url
      return yield
    ensure
      ThreadLocalCache.invalidate_slot_class 'bitchannel.request'
    end

    def read_only?
      @repository.read_only?
    end

    def locale
      @config.locale
    end

    def valid?(name)
      @repository.valid?(name)
    end

    def exist?(name)
      @repository.exist?(name)
    end

    def view(name)
      ViewPage.new(@config, @repository[name])
    end

    def viewrev(name, rev)
      ViewRevPage.new(@config, @repository[name], rev)
    end

    def edit(name)
      unless @repository.exist?(name)
        return edit_new(name)
      end
      page = @repository[name]
      rev = page.revision  # fix revision
      EditPage.new(@config, page, page.source(rev), rev)
    end

    def edit_revision(name, srcrev)
      page = @repository[name]
      EditPage.new(@config, page, page.source(srcrev), page.revision)
    end

    def edit_new(name)
      EditPage.new(@config, @repository.fetch(name), '', nil)
    end

    def edit_again(name, src, cirev, reason = :edit_conflicted)
      page = @repository[name]
      EditPage.new(@config, page, src, (cirev || page.revision), reason)
    end

    def preview(name, orgrev, text)
      PreviewPage.new(@config, @repository.fetch(name), text, orgrev)
    end

    def save(name, origrev, text)
      @repository.fetch(name).checkin origrev, text
      ThanksPage.new(@config, name)
    end

    def comment(name, user, cmt)
      @repository[name].edit {|text|
        insert_comment(text, user, cmt)
      }
      ThanksPage.new(@config, name)
    end

    def insert_comment(text, uname, comment)
      cmtline = "* #{format_time(Time.now)}: #{uname}: #{comment}"
      unless /\[\[\#comment(:.*?)?\]\]/n =~ text
        text << "\n" << cmtline
        return text
      end
      text.sub(/\[\[\#comment(:.*?)?\]\]/n) { $& + "\n" + cmtline }
    end
    private :insert_comment

    def diff(name, rev1, rev2)
      DiffPage.new(@config, @repository[name], rev1, rev2)
    end

    def history(name)
      HistoryPage.new(@config, @repository[name])
    end

    def annotate(name, rev)
      AnnotatePage.new(@config, @repository[name], rev)
    end

    def list
      ListPage.new(@config, @repository)
    end

    def recent
      RecentPage.new(@config, @repository)
    end

    def gdiff(org, reloadp)
      GlobalDiffPage.new(@config, @repository, org, reloadp)
    end

    def search(query, patterns)
      SearchResultPage.new(@config, @repository, query, patterns)
    end

    def search_error(query, err)
      SearchErrorPage.new(@config, query, err)
    end

    def src(name)
      page = @repository[name]
      TextPage.new(@config.locale, page.source, page.mtime)
    end

    def extent
      buf = ''
      @repository.pages.sort_by {|page| -page.mtime.to_i }.each do |page|
        buf << "= #{page.name}\r\n"
        buf << "\r\n"
        buf << page.source
        buf << "\r\n"
      end
      TextPage.new(@config.locale, buf, @repository.last_modified)
    end

  end

end
