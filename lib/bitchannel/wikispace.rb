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

module BitChannel

  class WikiSpace

    include TextUtils

    def initialize(config, repo)
      @config = config
      @repository = repo
    end

    def locale
      @config.locale
    end

    def suggest_cgi_url(u)
      @config.suggest_cgi_url u
    end

    def valid?(name)
      @repository.valid?(name)
    end

    def exist?(name)
      @repository.valid?(name) and @repository.exist?(name)
    end

    def view(name)
      ViewPage.new(@config, @repository, name)
    end

    def viewrev(name, rev)
      ViewRevPage.new(@config, @repository, page_name, rev)
    end

    def edit(name)
      rev = @repository.revision(name)
      EditPage.new(@config, @repository, name,
                   @repository.fetch(name, rev) { '' }, rev)
    end

    def edit_revision(name, srcrev)
      EditPage.new(@config, @repository, name,
                   @repository.fetch(name, srcrev) { '' },
                   @repository.revision(name))
    end

    def edit_new(name)
      EditPage.new(@config, @repository, name, '', nil)
    end

    def edit_again(name, src, cirev, reason = :edit_conflict)
      EditPage.new(@config, @repository, name,
                   src, cirev || @repository.revision(name), reason)
    end

    def preview(name, orgrev, text)
      PreviewPage.new(@config, @repository, name, text, orgrev)
    end

    def save(name, orgrev, text)
      @repository.checkin name, orgrev, text
      ThanksPage.new(@config, name)
    end

    def comment(name, user, cmt)
      @repository.edit(name) {|text|
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
      DiffPage.new(@config, @repository, name, rev1, rev2)
    end

    def history(name)
      HistoryPage.new(@config, @repository, name)
    end

    def annotate(name, rev)
      AnnotatePage.new(@config, @repository, name, rev)
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
      TextPage.new(@config.locale, @repository[name], @repository.mtime(name))
    end

    def extent
      buf = ''
      @repository.page_names.sort.each do |name|
        buf << "= #{name}\r\n"
        buf << "\r\n"
        buf << @repository[name]
        buf << "\r\n"
      end
      TextPage.new(@config.locale, buf, @repository.latest_mtime)
    end

  end

end
