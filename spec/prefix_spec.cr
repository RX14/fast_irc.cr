require "./spec_helper"

def parse_p(line)
  FastIRC::Prefix.parse(line)
end

def gen_p(nick, user, host)
  FastIRC::Prefix.new(nick, user, host)
end

describe FastIRC::Prefix do
  it "parses a nickmask" do
    assert parse_p("nick!user@host") == gen_p("nick", "user", "host")
  end

  it "supports missing username" do
    assert parse_p("nick@host") == gen_p("nick", nil, "host")
  end

  it "supports only having a nick" do
    assert parse_p("nick") == gen_p("nick", nil, nil)
  end

  it "parses nick+user" do
    assert parse_p("nick!user") == gen_p("nick", "user", nil)
  end

  it "detects servers" do
    assert parse_p("irc.example.org") == gen_p(nil, nil, "irc.example.org")
  end

  it "emits a basic nick properly" do
    assert gen_p("nick", nil, nil).to_s == "nick"
  end

  it "emits a nick with user" do
    assert gen_p("nick", "user", nil).to_s == "nick!user"
  end

  it "emits a nick with host" do
    assert gen_p("nick", nil, "host").to_s == "nick@host"
  end

  it "emits a full nick mask properly" do
    assert gen_p("nick", "user", "host").to_s == "nick!user@host"
  end

  it "emits a server" do
    assert gen_p(nil, nil, "host").to_s == "host"
  end
end
