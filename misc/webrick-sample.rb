#
# WEBrick servlet example (mounts on '/')
#

load './bitchannelrc'

require 'bitchannel/webrickservlet'
require 'webrick'

httpd = WEBrick::HTTPServer.new(
  :DocumentRoot => File::dirname(__FILE__),
  :Port         => 10080,
  :Logger       => WEBrick::Log.new($stderr, WEBrick::Log::DEBUG),
  :AccessLog    => [
    [ $stderr, WEBrick::AccessLog::COMMON_LOG_FORMAT  ],
    [ $stderr, WEBrick::AccessLog::REFERER_LOG_FORMAT ],
    [ $stderr, WEBrick::AccessLog::AGENT_LOG_FORMAT   ],
  ],
  :CGIPathEnv   => ENV["PATH"]
)
httpd.mount '/', BitChannel::WebrickServlet, *initialize_environment()

trap(:INT){ httpd.shutdown }
httpd.start
