#!/usr/bin/ruby
#
# $Id$
#
# Stand-alone server based on WEBrick
#

require 'optparse'

params = {
  :Port => 10080
}
cgidir = Dir.pwd
debugp = false

parser = OptionParser.new
parser.banner = "#{$0} [--port=NUM] [--cgidir=PATH] [--vardir=PATH] [--debug] [rcpath]"
parser.on('--port=NUM', 'Listening port number') {|num|
  params[:Port] = num.to_i
}
parser.on('--cgidir=PATH', 'The directory where bitchannelrc locate') {|path|
  cgidir = path
}
parser.on('--vardir=PATH', 'The directory for BitChannel working copy / cache') {|path|
  vardir = path
}
parser.on('--[no-]debug', 'Debug mode') {|flag|
  debugp = flag
}
parser.on('--help', 'Prints this message and quit') {
  puts parser.help
  exit 0
}
begin
  parser.parse!
rescue OptionParser::ParseError => err
  $stderr.puts err.message
  $stderr.puts parser.help
  exit 1
end

rcpath = ARGV[0] || "./bitchannelrc"
load File.expand_path(rcpath)
setup_environment
require 'webrick'
require 'bitchannel/webrickservlet'

if debugp
  params[:Logger] = WEBrick::Log.new($stderr, WEBrick::Log::DEBUG)
  params[:AccessLog] = [
    [ $stderr, WEBrick::AccessLog::COMMON_LOG_FORMAT  ],
    [ $stderr, WEBrick::AccessLog::REFERER_LOG_FORMAT ],
    [ $stderr, WEBrick::AccessLog::AGENT_LOG_FORMAT   ],
  ]
else
  params[:Logger] = WEBrick::Log.new($stderr, WEBrick::Log::INFO)
  params[:AccessLog] = []
end
server = WEBrick::HTTPServer.new(params)
server.mount '/', BitChannel::WebrickServlet, bitchannel_context()
server.mount '/theme/', WEBrick::HTTPServlet::FileHandler, "#{cgidir}/theme"
if debugp
  trap(:INT) { server.shutdown }
else
  WEBrick::Daemon.start
end
server.start
