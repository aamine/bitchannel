module BitChannel

  class Filter

    PRIMARY_RULE_FILE = 'filter.rb'

    def Filter.load_default
      load(PRIMARY_RULE_FILE)
    rescue Errno::ENOENT
      builtin()
    end

    def Filter.load(path)
      filter = new()
      filter.instance_eval(File.read(path), path)
      filter
    end

    def Filter.builtin
      filter = new()
      filter.install_builtin_rules
      filter
    end

    def initialize
      @denys = []
      @allows = []
    end

    def invalid?(data)
      deny = @denys.detect {|rule| rule.block.call(data) }
      unless deny
        return false
      end
      if @allows.any? {|rule| rule.call(data) }
        return false
      end
      deny.reason
    end

    TOO_LONG = 1024 * 1024   # 1MB

    def install_builtin_rules
      install_builtin_edit_rules
      install_builtin_comment_rules
    end

    def install_builtin_edit_rules
      deny('Too long page') {|data| data.text.size > TOO_LONG }
    end

    def install_builtin_comment_rules
      deny_comment('Too long comment') {|data| data.text.size > 4098 }
      deny_comment('Empty comment') {|data| data.text.strip.empty? }
      deny_comment('Too many URLs') {|data|
        data.text.scan(/https?:/i).size > 3
      }
      deny_comment('wrong link format') {|data| %r<\[/url\]>i =~ data.text }
    end

    Deny = Struct.new(:reason, :block)

    def deny(reason, &block)
      @denys.push Deny.new(reason, block)
    end

    def deny_comment(reason, &block)
      rule = lambda {|data| data.comment? and block.call(data) }
      @denys.push Deny.new(reason, rule)
    end

    def deny_edit(reason, &block)
      rule = lambda {|data| data.edit? and block.call(data) }
      @denys.push Deny.new(reason, rule)
    end

    def freeze_page(name)
      deny_edit('This page is frozen') {|data| data.page_name == name }
    end

    def allow(&block)
      @allows.push block
    end

  end

end
