require "./spec_helper"

def parse_m(line)
    FastIRC::Message.parse(line)
end

def gen_m(sender, command, params = nil, tags = nil)
    prefix = nil
    if sender
        match = sender.match(/^([^!@]+)(?:(?:!([^@]+))?@(.+))?$/)
        if match
            prefix = FastIRC::Prefix.new(match[1], match[2]?, match[3]?)
        end
    end
    FastIRC::Message.new(tags, prefix, command, params)
end

describe FastIRC::Message do

    it "does not fail when accessing any of its getters" do
      msg = parse_m(":nick!user@host PRIVMSG #channel :test message")
      assert msg.prefix == FastIRC::Prefix.new("nick", "user", "host")
      assert msg.command == "PRIVMSG"
      assert msg.params == ["#channel", "test message"]
    end

    it "properly lets inpect itself" do
      assert gen_m("sender!user@host", "command", ["param1"]).inspect == "Message(@tags=nil, @prefix=Prefix(@target=\"sender\", @user=\"user\", @host=\"host\"), @command=\"command\", @params=[\"param1\"])"
    end

    it "parses a basic message" do
        assert parse_m("PING 1234") == gen_m(nil, "PING", ["1234"])
    end

    it "parses a typical chat message" do
        assert parse_m(":nick!user@host PRIVMSG #channel :test message") == gen_m("nick!user@host", "PRIVMSG", ["#channel", "test message"])
    end

    it "parses a not so typical chat message" do
        assert parse_m(":nick!user@host PRIVMSG #channel test") == gen_m("nick!user@host", "PRIVMSG", ["#channel", "test"])
    end

    it "parses an irv3 annotated chat message" do
        assert parse_m("@account=account\\sowner :nick!user@host PRIVMSG #channel :test message") == gen_m("nick!user@host", "PRIVMSG", ["#channel", "test message"], {"account" => "account owner"})
    end

    it "parses a very complex ircv3 message" do
        assert parse_m("@account=account\\sowner;kilobyte22.de/custom_flag :sender 1337 param1 param2 param3 param4 param5 param6 :param 7") == gen_m(
            "sender",
            "1337",
            ["param1", "param2", "param3", "param4", "param5", "param6", "param 7"],
            {"account": "account owner", "kilobyte22.de/custom_flag": nil}
        )
    end

    it "emits a basic message" do
        assert gen_m(nil, "PING", ["1234"]).to_s == "PING 1234"
    end

    it "properly detects last param starting with a colon" do
        assert gen_m(nil, "PING", [":stuff"]).to_s == "PING ::stuff"
    end

    it "properly detects last param containing a space" do
        assert gen_m(nil, "PING", ["stuff with space"]).to_s == "PING :stuff with space"
    end

    it "properly detects last param being empty" do
        assert gen_m(nil, "PING", [""]).to_s == "PING :"
    end

    it "properly outputs the prefix" do
        assert gen_m("prefix", "PING").to_s == ":prefix PING"
    end

    it "properly outputs parameterless ircv3 tags" do
        assert gen_m(nil, "PING", [] of String, {"test": nil}).to_s == "@test PING"
    end

    it "properly outputs parameterized ircv3 tags" do
        assert gen_m(nil, "PING", [] of String, {"foo": "bar"}).to_s == "@foo=bar PING"
    end

    it "properly encodes tag values during output" do
        assert gen_m(nil, "PING", [] of String, {"test": " \\\n;"}).to_s == "@test=\\s\\\\\\n\\: PING"
    end

    it "properly encodes multiple tags" do
        assert gen_m(nil, "PING", [] of String, {"foo": "bar", "baz": nil}).to_s == "@foo=bar;baz PING"
    end

    it "parses sample messages" do
        File.each_line(__DIR__ + "/irc_lines.txt") do |line|
            parse_m(line.strip)
        end
    end
end
