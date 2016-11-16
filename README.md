[![Travis CI](https://img.shields.io/travis/RX14/fast_irc.cr.svg)](https://travis-ci.org/RX14/fast_irc.cr)
# fast_irc.cr

An optimised IRC parsing library for crystal. Supports IRCv3 message tags. Getting started is as easy as `FastIRC.parse(io) do |message|`.

Fast_irc doesn't attempt to deal with the semantics of IRC messages. Messages are simply parsed into a machine-readable format and delivered to the user.

## Performance

Here fast_irc was tested parsing a `63748` byte IRC log file collected from real IRC activity on the esper.net IRC network. Fast_irc's performance on a single core averaged over 150MB/s, taking only 740 nanoseconds to parse a single line.

In terms of memory performance, a single 8192 byte buffer is allocated per connection. All string values in the IRC prefix, the IRC command, and IRCv3 tag *keys* are interned in a global string pool to save memory. IRCv3 message tag values and IRC command parameters are not interned.

## Installation

Add it to `shard.yml`

```yaml
dependencies:
  fast_irc:
    github: RX14/fast_irc.cr
    version: 0.3.0
```

## Docs

Build the documentation by cloning this repo and running `crystal doc`. HTML documentation will be placed in `doc/`.

## Usage

It's easy to get started parsing IRC connections right away using fast_irc. Just pass an `IO` (likely a TCP connection to an IRC server) to `FastIRC.parse`. `Message` objects are yielded as they arrive on the connection. For a non-block way to read messages, see `FastIRC::Reader`.

```cr
FastIRC.parse(io) do |message|
  message.command       # => "PRIVMSG" : String
  message.params        # => ["#crystal-lang", "Test message using fast_irc.cr!"] : Array(String)?
  message.prefix.source # => "RX14" : String
end
```

Generating IRC is just as easy. Create your `Message` object and call `to_s`.

```cr
FastIRC::Message.new("PRIVMSG", ["#WAMM", "test message"]).to_s(io)
```

You can also add IRCv3 tags and a prefix. `FastIRC::Tags` is simply an alias for `Hash(String, String?)`. It is recommended to use the `FastIRC::Tags` alias when creating tags hashes both to clear intent, and to make sure that you don't end up with a `Hash(String, String)` instead, which is a binary-incompatible type.

```cr
prefix = FastIRC::Prefix.new(source: "RX14", user: "rx14", host: "rx14.co.uk")
tags = FastIRC::Tags{"time" => "2016-11-11T22:27:15Z"}
FastIRC::Message.new("PRIVMSG", ["#WAMM", "test message"], prefix: prefix, tags: tags).to_s(io)
```

## Contributing

1. Fork it ( https://github.com/RX14/fast_irc/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [RX14](https://github.com/RX14) Chris Hobbs - creator, maintainer
- [Kilobyte22](https://github.com/Kilobyte22) Stephan Henrichs - IRC serialisation, specs
