#
# $Id$
#
# Copyright (C) 2003,2004 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'erb'

class ERB   # tmp
  attr_accessor :filename  unless method_defined?(:filename)

  remove_method :result
  def result(binding)
    eval(@src, binding, @filename, 1)
  end
end

module BitChannel

  module ErbUtils
    private

    def run_erb(templatedir, id)
      erb = ERB.new(get_template(templatedir, id), nil, 2)
      erb.filename = "#{id}.rhtml"
      erb.result(binding())
    end

    def get_template(tmpldir, tmplname)
      File.read("#{tmpldir}/#{tmplname}.rhtml").gsub(/^\.include (\w+)/) {
        get_template(tmpldir, $1.untaint)
      }.untaint
    end
  end

end
