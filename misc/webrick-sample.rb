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
  :CGIPathEnv   => ENV["PATH"]   # PATH environment variable for CGI.
)

env = Object.new
env.instance_eval(File.read('bitchannelrc'), 'bitchannelrc')
config, repo = *env.initialize_environment
require 'bitchannel/webrickservlet'
BitChannel::WebrickServlet.set_environment config, repo
httpd.mount '/', BitChannel::WebrickServlet

trap(:INT){ httpd.shutdown }
httpd.start
