#!/usr/bin/ruby
# stand-alone server based on WEBrick

rcpath = ARGV[0] || './bitchannelrc'
load File.expand_path(rcpath)
setup_environment
require 'webrick'
require 'bitchannel/webrickservlet'

server = WEBrick::HTTPServer.new(
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
server.mount '/', BitChannel::WebrickServlet, *bitchannel_context()
trap(:INT){ server.shutdown }
server.start
