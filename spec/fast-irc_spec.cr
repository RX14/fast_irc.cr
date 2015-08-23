require "./spec_helper"

def parse(line)
    FastIrc::Message.parse(line)
end

def gen(sender, command, params = [] of String, tags = {} of String => String|Nil)
    prefix = nil
    if sender
        match = sender.match(/^([^!@]+)(?:(?:!([^@]+))?@(.+))?$/)
        if match
            prefix = FastIrc::Prefix.new(match[1], match[2]?, match[3]?)
        end
    end
    FastIrc::Message.new(prefix, command, params)
end

describe FastIrc::Message do
    it "parses a basic message" do
        parse("PING 1234").should eq(gen(nil, "PING", ["1234"]))
    end

    it "parses a typical chat message" do
        parse(":nick!user@host PRIVMSG #channel :test message").should eq(gen("nick!user@host", "PRIVMSG", ["#channel", "test message"]))
    end

    it "parses a not so typical chat message" do
        parse(":nick!user@host PRIVMSG #channel test").should eq(gen("nick!user@host", "PRIVMSG", ["#channel", "test"]))
    end

#    it "parses an irv3 annotated chat message" do
#        parse("@account=account\\sowner :nick!user@host PRIVMSG #channel :test message").should eq(gen("nick!user@host", "PRIVMSG", ["#channel", "test message"], {"account" => "account owner"}))
#    end
#
#    it "parses a very complex ircv3 message" do
#        parse("@account=account\\sowner;kilobyte22.de/custom_flag :sender 1337 param1 param2 param3 param4 param5 param6 :param 7").should eq(gen(
#            "sender",
#            "1337",
#            ["param1", "param2", "param3", "param4", "param5", "param6", "param 7"],
#            {"account": "account owner", "kilobyte22.de/custom_flag": nil}
#        ))
#    end

    it "emits a basic message" do
        gen(nil, "PING", ["1234"]).to_irc.should eq("PING 1234")
    end

    it "properly detects invalid parameter in last position" do
        gen(nil, "PING", [":stuff"]).to_irc.should eq("PING ::stuff")
        gen(nil, "PING", ["stuff with space"]).to_irc.should eq("PING :stuff with space")
        gen(nil, "PING", [""]).to_irc.should eq("PING :")
    end

    it "properly outputs the prefix" do
        gen("prefix", "PING").to_irc.should eq(":prefix PING")
    end

#    it "properly outputs parameterless ircv3 tags" do
#        gen(nil, "PING", [] of String, {"test": nil}).to_irc.should eq("@test PING")
#    end
#
#    it "properly outputs parameterized ircv3 tags" do
#        gen(nil, "PING", [] of String, {"foo": "bar"}).to_irc.should eq("@foo=bar PING")
#    end
#
#    it "properly encodes tag values during output" do
#        gen(nil, "PING", [] of String, {"test": " \\\n\0;"}).to_irc.should eq("@test=\\s\\\\\\n\\0\\: PING")
#    end
#
#    it "properly encodes multiple tags" do
#        gen(nil, "PING", [] of String, {"foo": "bar", "baz": nil}).to_irc.should eq("@foo=bar;baz PING")
#    end
end
