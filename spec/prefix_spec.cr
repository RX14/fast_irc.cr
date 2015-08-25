def parse(line)
  FastIRC::Prefix.parse(line)
end

def gen(nick, user, host)
  FastIRC::Prefix.new(nick, user, host)
end

describe FastIRC::Prefix do
  it "parses a nickmask" do
    parse("nick!user@host").should eq(gen("nick", "user", "host"))
  end

  it "supports missing username" do
    parse("nick@host").should eq(gen("nick", nil, "host"))
  end

  it "supports only having a nick" do
    parse("nick").should eq(gen("nick", nil, nil))
  end

  it "parses nick+user" do
    parse("nick!user").should eq(gen("nick", "user", nil))
  end

  it "detects servers" do
    parse("irc.example.org").should eq(gen(nil, nil, "irc.example.org"))
  end

  it "emits a basic nick properly" do
    gen("nick", nil, nil).to_s.should eq("nick")
  end

  it "emits a nick with user" do
    gen("nick", "user", nil).to_s.should eq("nick!user")
  end

  it "emits a nick with host" do
    gen("nick", nil, "host").to_s.should eq("nick@host")
  end

  it "emits a full nick mask properly" do
    gen("nick", "user", "host").to_s.should eq("nick!user@host")
  end

  it "emits a server" do
    gen(nil, nil, "host").to_s.should eq("host")
  end
end
