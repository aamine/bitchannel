#!/usr/bin/env ruby
#
# $Id$
#
# count bitchannel commands from Apache's access.log
#

table = Hash.new(0)
ARGF.each do |line|
  cmd = line.slice(%r<\?cmd=(\w+)>, 1)
  table[cmd] += 1 if cmd
end
table.to_a.sort_by {|cmd, num| -num }.each do |cmd, num|
  printf "%-10s %4d\n", cmd, num
end
