require "spec"
require "power_assert"
require "../src/fast_irc"

IRC_LINES = File.read_lines(__DIR__ + "/irc_lines.txt").map &.strip
