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
require 'bitchannel/repository'
require 'bitchannel/handler'
require 'bitchannel/webrick_cgi'
require 'fileutils'
require 'forwardable'

module BitChannel

  class FarmCGI < WEBrick::CGI

    def FarmCGI.main(farm)
      super({}, farm)
    end

    def init_application(farm)
      @farm = farm
    end

    def do_GET(req, res)
      handle(req).update_for res
    end

    alias do_POST do_GET

    private

    def handle(webrickreq)
      req = FarmRequest.new(webrickreq)
      case
      when req.cascade?
        return farm_index() unless @farm.exist?(req.node_id)
        webrickreq.query['name'] ||= req.page_name
        wiki = @farm[req.node_id]
        Handler.new(wiki).handle(Request.new(webrickreq, wiki.locale, false))
      when req.new_node?
        @farm.create_node req.id, { :name => req.name,
                                    :theme => req.theme,
                                    :logo => nil }
        FarmThanksPage.new(@farm, req.id).response
      else
        farm_index()
      end
    end

    def farm_index
      FarmIndexPage.new(@farm).response
    end

  end


  class FarmRequest

    def initialize(webrickreq)
      @request = webrickreq
    end

    def cascade?
      node_id() ? true : false
    end

    def node_id
      node, page = *parse_pathinfo()
      return nil unless node
      invalidate_token(node)
    end

    def page_name
      node, page = *parse_pathinfo()
      return nil unless page
      return nil if page.empty?
      page = page.sub(/\.html?\z/, '')
      return nil if page.empty?
      page
    end

    def new_node?
      @request.query.key?('create')
    end

    def id
      get_token('id')
    end

    def name
      str = get('name').to_s.strip
      return nil if str.empty?
      str
    end

    def theme
      get_token('theme')
    end

    private

    def parse_pathinfo
      return nil unless @request.path_info
      empty, node, page, *rest = *@request.path_info.split('/', -1)
      return nil unless rest.empty?
      return node, page
    end

    def get_token(name)
      invalidate_token(@request.query[name].to_s.strip)
    end

    def invalidate_token(tok)
      return nil if tok.empty?
      return nil if /[^a-zA-Z0-9\-]/ =~ tok
      return nil if tok.length > 128
      tok
    end

    def get(name)
      val = @request.query[name]
      return nil unless val
      return nil if val.empty?
      val.to_s
    end

  end


  class FarmPage < RhtmlPage

    def initialize(farm)
      super farm.config
      @farm = farm
    end

    private

    def node_url(id)
      escape_html("#{@config.node_urlbase}/#{id}/")
    end

    def farm_url
      escape_html(@config.farm_url)
    end

  end


  class FarmIndexPage < FarmPage

    def last_modified
      @farm.last_modified
    end

    private

    def template_id
      'farm'
    end

    def node_ids
      @farm.node_ids
    end
    
    def mtime(id)
      @farm[id].last_modified
    end

    def name(id)
      @farm[id].name
    end

  end


  class FarmThanksPage < FarmPage

    def initialize(farm, id)
      super farm
      @id = id
    end

    private

    def template_id
      'farmthanks'
    end

    def node
      @id
    end

  end


  class FarmConfig

    def initialize(hash)
      UserConfig.parse(hash, 'farmconf') {|conf|
        @farm_url      = conf.get_required(:farm_url)
        @node_urlbase  = conf.get_required(:node_urlbase)
        @theme_urlbase = conf.get_required(:theme_urlbase)
        @themedir      = conf.get_required(:themedir)
        @templatedir   = conf.get_required(:templatedir)
        @locale        = conf.get_required(:locale)
      }
    end

    attr_reader :farm_url
    attr_reader :node_urlbase
    attr_reader :templatedir
    attr_reader :locale

    def themes
      Dir.glob("#{@themedir}/*/").map {|path| File.basename(path) }
    end

    def theme?(name)
      File.directory?("#{@themedir}/#{encode_filename(name)}")
    end

    def css_url(theme = 'default')
      "#{@theme_urlbase}/#{theme}/#{theme}.css"
    end

  end


  class Farm

    include FilenameEncoding

    def initialize(config, hash)
      @config = config
      UserConfig.parse(hash, 'farm') {|conf|
        @datadir     = conf.get_required(:datadir)
        @cmd_path    = conf.get_required(:cmd_path)
        @repository  = conf.get_required(:repository)
        @skeleton    = conf.get_required(:skeleton)
        @logfile     = conf.get_optional(:logfile, nil)
      }
      @nodes = {}
    end

    attr_reader :config

    def create_node(id, prop)
      tmpprefix = "#{@datadir}/.#{id}"
      begin
        Dir.mkdir tmpprefix
      rescue Errno::EEXIST
        raise NodeExist, "node `#{id}' already exists"
      end
      if File.directory?(prefix(id))
        Dir.rmdir tmpprefix
        raise NodeExist, "node `#{id}' already exists"
      end
      Dir.mkdir "#{tmpprefix}/cache"
      repo = Repository.new({
        :cmd_path     => @cmd_path,
        :wc_read      => "#{tmpprefix}/wc.read",
        :wc_write     => "#{tmpprefix}/wc.write",
        :cachedir     => "#{tmpprefix}/cache",
        :logfile      => @logfile,
        :id           => id
      })
      repo.setup_working_copy @repository
      Dir.glob("#{@skeleton}/*").select {|n| File.file?(n) }.each do |path|
        repo.checkin decode_filename(File.basename(path)), nil, File.read(path)
      end
      repo.properties = prop
      File.rename tmpprefix, prefix(id)
    ensure
      unless File.directory?(prefix(id))
        FileUtils.rm_rf tmpprefix
      end
    end

    def last_modified
      node_ids().map {|id| File.mtime(prefix(id)) }.sort.last
    end

    def node_ids
      Dir.entries(@datadir).select {|ent|
        not /\A\./ =~ ent and File.directory?(prefix(ent))
      }
    end

    def exist?(id)
      File.directory?(prefix(id))
    end

    def [](id)
      @nodes[id] ||= new_node(id)
    end

    private

    def new_node(id)
      repo = Repository.new({
        :cmd_path     => @cmd_path,
        :wc_read      => "#{prefix(id)}/wc.read",
        :wc_write     => "#{prefix(id)}/wc.write",
        :cachedir     => "#{prefix(id)}/cache",
        :logfile      => @logfile
      }, id)
      conf = Config.new({
        :templatedir   => @config.templatedir,
        :cgi_url       => "#{@config.node_urlbase}/#{id}/",
        :use_html_url  => "",
        :locale        => @config.locale,
        :css_url       => @config.css_url(repo.theme),
        :site_name     => repo.name,
        :logo_url      => repo.logo
      })
      WikiSpace.new(conf, repo)
    end

    def prefix(id)
      "#{@datadir}/#{id}"
    end

  end   # class Farm


  class WikiSpace   # redefine
    extend Forwardable
    def_delegator "@repository", :last_modified
    def_delegator "@repository", :name
    def_delegator "@repository", :logo
    def_delegator "@repository", :theme
  end


  class Repository   # redefine

    def setup_working_copy(repopath)
      Dir.mkdir File.dirname(@wc_read) + '/tmp'
      Dir.chdir(File.dirname(@wc_read) + '/tmp') {
        log = 'BitChannelFarm auto import'
        cvs '-d', repopath, 'import', '-m',log, @module_id, 'bcfarm', 'start'
      }
      Dir.rmdir File.dirname(@wc_read) + '/tmp'
      Dir.chdir(File.dirname(@wc_read)) {
        cvs '-d', repopath, 'co', '-d', File.basename(@wc_read), @module_id
        cvs '-d', repopath, 'co', '-d', File.basename(@wc_write), @module_id
      }
    end

    def name
      getprop(:name)
    end

    def theme
      getprop(:theme)
    end

    def logo
      getprop(:logo)
    end

    def properties=(hash)
      write_properties hash
    end

    private

    def getprop(key)
      @properties ||= read_properties()
      @properties[key]
    end

    PROPERTY_FILE = 'properties'

    def read_properties
      result = {}
      File.readlines("#{prefix()}/#{PROPERTY_FILE}").each do |line|
        k, v = line.split(':', 2)
        result[k.intern] = eval(v.untaint)
      end
      result
    end

    def write_properties(prop)
      path = "#{prefix()}/#{PROPERTY_FILE}"
      File.open(path + '.tmp', 'w') {|f|
        prop.each do |k,v|
          f.puts "#{k}: #{dump_property(v)}"
        end
      }
      File.rename path + '.tmp', path
    end

    def dump_property(val)
      case val
      when String
        val.dump
      when nil, true, false
        val.inspect
      else
        raise "must not happen: dump_property(#{val.class})"
      end
    end

    def prefix
      File.dirname(@wc_read)
    end

  end

end
