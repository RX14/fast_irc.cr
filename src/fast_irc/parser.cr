require "string_pool"

module FastIRC
  @@pool = StringPool.new

  # Exception raised when parsing an IRC message fails.
  class ParseException < Exception
  end

  # Parses a single IRC message, excluding crlf terminator. Set *strict* to be
  # true to enforce line length limits and raise in various other conditions.
  def self.parse_line(str : Slice(UInt8), *, strict = false) : Message
    ptr_ircv3_start = str.to_unsafe.address
    if str[0] == '@'.ord
      # Parse IRCv3 tags
      tags = Tags.new

      # Shouldn't need check str.size because of the check_end calls below
      until str[0] == ' '.ord
        # We start the loop on the character *before* the start of an IRCv3 tag
        str += 1

        key, str = read_string_until(str, ';', '=', ' ')
        check_end(str, "reading IRCv3 tag key")

        if str[0] == '='.ord
          str += 1
          check_end(str, "reading IRCv3 tag")

          tags[key], str = read_ircv3_tag_value(str)
          check_end(str, "reading IRCv3 tag value")
        else
          tags[key] = nil
        end
      end

      # Skip the space after the tags
      str += 1
    end

    ircv3_size = str.to_unsafe.address - ptr_ircv3_start
    raise ParseException.new "IRCv3 tags were #{ircv3_size} bytes long, but the maximum allowed size is 512 bytes" if strict && ircv3_size > 512
    raise ParseException.new "IRC message is #{str.size} bytes long, but the maximum allowed size is 510 bytes (not including crlf)" if strict && str.size > 510

    if str[0] == ':'.ord
      str += 1
      check_end(str, "reading prefix")

      source, str = read_string_until(str, ' ', '!', '@')
      check_end(str, "reading prefix source")

      if str[0] == '!'.ord
        user, str = read_string_until(str + 1, ' ', '@')
        check_end(str, "reading prefix user")
      end

      if str[0] == '@'.ord
        host, str = read_string_until(str + 1, ' ')
        check_end(str, "reading prefix host")
      end

      prefix = Prefix.new(source: source, user: user, host: host)

      # Skip space after prefix
      str += 1
    end

    command, str = read_string_until(str, ' ')

    if str.size > 0
      params = Array(String).new(5)
      while str.size > 0
        # We start the loop at the character *before* a parameter
        str += 1

        # Check for duplicate whitespace
        while !strict && str.size > 0 && str[0] == ' '
          str += 1
        end
        break if str.size == 0

        if str[0] == ':'.ord
          param = String.new(str + 1)
          params << param
          break
        end

        param, str = read_string_until(str, ' ', intern: false)
        params << param
      end
    end

    Message.new(command, params, prefix: prefix, tags: tags)
  end

  # ditto
  def self.parse_line(str : String, *, strict = false)
    parse_line(str.to_slice, strict: strict)
  end

  private def self.read_ircv3_tag_value(str)
    value = String.build do |io|
      until str.size == 0 || str[0] == ';'.ord || str[0] == ' '.ord
        if str[0] == '\\'.ord && str.size > 1
          str += 1

          # Start of escape
          case str[0]
          when ':'.ord
            io.write_byte ';'.ord.to_u8
          when 's'.ord
            io.write_byte ' '.ord.to_u8
          when '\\'.ord
            io.write_byte '\\'.ord.to_u8
          when 'r'.ord
            io.write_byte '\r'.ord.to_u8
          when 'n'.ord
            io.write_byte '\n'.ord.to_u8
          else
            raise ParseException.new("Invalid escape sequence: \\#{str[1]}")
          end
        else
          io.write_byte str[0]
        end

        str += 1
      end
    end

    {value, str}
  end

  @[AlwaysInline]
  private def self.check_end(slice, message)
    raise ParseException.new("Invalid end of line while #{message}") if slice.size == 0
  end

  @[AlwaysInline]
  private def self.read_string_until(slice, *chars, intern = true)
    read_string_until(slice) do |byte|
      chars.any? { |c| byte == c.ord }
    end
  end

  @[AlwaysInline]
  private def self.read_string_until(slice, intern = true)
    i = 0
    while i < slice.size && !(yield slice[i])
      # p slice[i].chr
      i += 1
    end

    if intern
      {@@pool.get(slice[0, i]), slice + i}
    else
      {String.new(slice[0, i]), slice + i}
    end
  end
end
