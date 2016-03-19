require "spec"
require "power_assert"
require "../src/fast_irc"

@@irc_lines = File.read_lines(__DIR__ + "/irc_lines.txt").map &.strip
