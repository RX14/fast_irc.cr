require "./spec_helper"

def parse_m(line, strict = false)
  FastIRC.parse_line(line.to_slice, strict: strict)
end

def gen_m(sender, command, params = nil, tags = nil)
  tags = tags.try &.map { |k, v| {k, v.as(String?)} }.to_h
  prefix = nil
  if sender
    match = sender.match(/^([^!@]+)(?:(?:!([^@]+))?@(.+))?$/)
    if match
      prefix = FastIRC::Prefix.new(source: match[1], user: match[2]?, host: match[3]?)
    end
  end
  FastIRC::Message.new(command, params, prefix: prefix, tags: tags)
end

describe FastIRC::Message do
  it "does not fail when accessing any of its getters" do
    msg = parse_m(":nick!user@host PRIVMSG #channel :test message")
    msg.prefix.should eq(FastIRC::Prefix.new(source: "nick", user: "user", host: "host"))
    msg.command.should eq("PRIVMSG")
    msg.params.should eq(["#channel", "test message"])
  end

  it "properly lets inpect itself" do
    gen_m("sender!user@host", "command", ["param1"]).inspect.should eq("Message(@tags=nil, @prefix=Prefix(@source=\"sender\", @user=\"user\", @host=\"host\"), @command=\"command\", @params=[\"param1\"])")
  end

  it "parses a basic message" do
    parse_m("PING 1234").should eq(gen_m(nil, "PING", ["1234"]))
  end

  it "parses a typical chat message" do
    parse_m(":nick!user@host PRIVMSG #channel :test message").should eq(gen_m("nick!user@host", "PRIVMSG", ["#channel", "test message"]))
  end

  it "parses a not so typical chat message" do
    parse_m(":nick!user@host PRIVMSG #channel test").should eq(gen_m("nick!user@host", "PRIVMSG", ["#channel", "test"]))
  end

  it "parses an irv3 annotated chat message" do
    parse_m("@account=account\\sowner :nick!user@host PRIVMSG #channel :test message").should eq(gen_m("nick!user@host", "PRIVMSG", ["#channel", "test message"], {"account" => "account owner"}))
  end

  it "parses a very complex ircv3 message" do
    parse_m("@account=account\\sowner;kilobyte22.de/custom_flag :sender 1337 param1 param2 param3 param4 param5 param6 :param 7").should eq(gen_m(
      "sender",
      "1337",
      ["param1", "param2", "param3", "param4", "param5", "param6", "param 7"],
      {"account" => "account owner", "kilobyte22.de/custom_flag" => nil}
    ))
  end

  it "raises when the line is too long" do
    message = ":maxpowa!is@weeb PRIVMSG #WAMM :#{"incoherent weebshit" * 300}"
    ircv3 = "@foo=#{"bar" * 300}"

    expect_raises(FastIRC::ParseException, "IRC message is #{message.size} bytes long, but the maximum allowed size is 510 bytes (not including crlf)") do
      parse_m(message, strict: true)
    end

    expect_raises(FastIRC::ParseException, "IRC message is 511 bytes long, but the maximum allowed size is 510 bytes (not including crlf)") do
      parse_m(message[0, 511], strict: true)
    end

    parse_m(message[0, 510], strict: true)
  end

  it "raises when the line is too long (ircv3)" do
    message = ":maxpowa!is@weeb PRIVMSG #WAMM :#{"incoherent weebshit" * 300}"
    ircv3 = "@foo=#{"bar" * 300}"

    expect_raises(FastIRC::ParseException, "IRCv3 tags were #{ircv3.size + 1} bytes long, but the maximum allowed size is 512 bytes") do
      parse_m(ircv3 + " " + message[0, 510], strict: true)
    end

    expect_raises(FastIRC::ParseException, "IRCv3 tags were #{ircv3.size + 1} bytes long, but the maximum allowed size is 512 bytes") do
      parse_m(ircv3 + " " + message, strict: true)
    end

    expect_raises(FastIRC::ParseException, "IRCv3 tags were 513 bytes long, but the maximum allowed size is 512 bytes") do
      parse_m(ircv3[0, 512] + " " + message[0, 510], strict: true)
    end

    expect_raises(FastIRC::ParseException, "IRCv3 tags were 513 bytes long, but the maximum allowed size is 512 bytes") do
      parse_m(ircv3[0, 512] + " " + message, strict: true)
    end

    parse_m(ircv3[0, 511] + " " + message[0, 510], strict: true)
  end

  it "emits a basic message" do
    gen_m(nil, "PING", ["1234"]).to_s.should eq("PING 1234\r\n")
  end

  it "properly detects last param starting with a colon" do
    gen_m(nil, "PING", [":stuff"]).to_s.should eq("PING ::stuff\r\n")
  end

  it "properly detects last param containing a space" do
    gen_m(nil, "PING", ["stuff with space"]).to_s.should eq("PING :stuff with space\r\n")
  end

  it "properly detects last param being empty" do
    gen_m(nil, "PING", [""]).to_s.should eq("PING :\r\n")
  end

  it "properly outputs the prefix" do
    gen_m("prefix", "PING").to_s.should eq(":prefix PING\r\n")
  end

  it "properly outputs parameterless ircv3 tags" do
    gen_m(nil, "PING", [] of String, {"test" => nil}).to_s.should eq("@test PING\r\n")
  end

  it "properly outputs parameterized ircv3 tags" do
    gen_m(nil, "PING", [] of String, {"foo" => "bar"}).to_s.should eq("@foo=bar PING\r\n")
  end

  it "properly encodes tag values during output" do
    gen_m(nil, "PING", [] of String, {"test" => " \\\n;"}).to_s.should eq(%q(@test=\s\\\n\: PING) + "\r\n")
  end

  it "properly encodes multiple tags" do
    gen_m(nil, "PING", [] of String, {"foo" => "bar", "baz" => nil}).to_s.should eq("@foo=bar;baz PING\r\n")
  end

  it "parses sample messages" do
    IRC_LINES.each do |line|
      parse_m(line)
    end
  end

  it "reconstructs parsed messages" do
    IRC_LINES.each do |line|
      msg = parse_m(line)
      msg.to_s.should eq(line + "\r\n")
    end
  end
end
