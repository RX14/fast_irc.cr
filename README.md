[![Travis CI](https://img.shields.io/travis/RX14/fast-irc.cr.svg)](https://travis-ci.org/RX14/fast-irc.cr)
# fast-irc.cr

A fast IRC parsing library for crystal.

## Installation

Add it to `Projectfile`

```crystal
deps do
  github "RX14/fast-irc.cr"
end
```

## Usage

```crystal
require "fast-irc"

message = FastIrc::Message.parse ":nick!user@host COMMAND arg1 arg2 :arg3 ;)"
message.command # "COMMAND"
message.args    # ["arg1", "arg2", "arg3 ;)"]
message.prefix  # Prefix(@target="nick", @user="user", @host="host")
```

## Development

TODO: Write instructions for development

## Contributing

1. Fork it ( https://github.com/RX14/fast-irc/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [RX14](https://github.com/RX14) RX14 - creator, maintainer
