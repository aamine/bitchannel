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
      install_builtin_rules filter
      filter
    end

    TOO_LONG = 1024 * 1024   # 1MB

    def Filter.install_builtin_rules(filter)
      install_builtin_edit_rules filter
      install_builtin_comment_rules filter
    end

    def Filter.install_builtin_edit_rules(filter)
      filter.deny('Too long page') {|data| data.text.size > TOO_LONG }
    end

    def Filter.install_builtin_comment_rules(filter)
      filter.deny_comment('Too long comment') {|data| data.text.size > 4098 }
      filter.deny_comment('Empty comment') {|data| data.text.strip.empty? }
      filter.deny_comment('Too many URLs') {|data|
        data.text.scan(/https?:/i).size > 3
      }
      filter.deny_comment('wrong link format') {|data| /\[url=/ =~ data.text }
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

    def install_builtin_rules
      Filter.install_builtin_rules self
    end

    def install_builtin_edit_rules
      Filter.install_builtin_edit_rules self
    end

    def install_builtin_comment_rules
      Filter.install_builtin_comment_rules self
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

    def allow(&block)
      @allows.push block
    end

  end

end
