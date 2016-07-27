private macro parse_prefix
  is_host = false
  target = parse_field do
    read_until ' ', '!', '@', '.'
    if cur == '.'.ord
      is_host = true
      read_until ' ', '!', '@'
    end
  end

  if is_host
    host = target
    target = nil
  end

  if cur == '!'.ord
    incr
    user = parse_field { read_until ' ', '@' }
  end

  if cur == '@'.ord
    incr
    host = parse_field { read_until ' ' }
  end

  prefix = Prefix.new(target, user, host)
end

module FastIRC
  class ParseError < Exception
    def initialize(message : String)
      super("Failed to parse IRC message #{message.inspect}")
    end
  end

  class Message
    include ParserHelpers

    # Parses an IRC Message from a Slice(UInt8).
    # The slice should not have trailing \r\n characters and should be null terminated.
    def self.parse(str : Slice(UInt8))
      raise "IRC message is not null terminated" if str[-1] != 0
      pos = 0
      cur = str[pos]

      prefix = nil

      if cur == '@'.ord
        incr

        tags_start = pos
        read_until ' '

        incr
      end

      if cur == ':'.ord
        incr

        parse_prefix

        incr
      end

      command = parse_field { read_until ' ' }

      unless cur == 0
        incr

        params_start = pos
      end

      Message.new(str, tags_start, prefix, command, params_start)
    rescue
      raise ParseError.new(String.new(str))
    end

    # Parses an IRC message from a String.
    # The String should not have the trailing "\r\n" characters.
    def self.parse(str)
      parse Slice.new(str.to_unsafe, str.bytesize + 1)
    end

    def initialize(@str : Bytes, @tags_start : Int32?, @prefix, @command, @params_start : Int32?)
    end

    private def parse_params
      if pos = @params_start
        str = @str

        cur = str[pos]

        params = [] of String
        while true
          str_start = pos
          if cur == ':'.ord
            str_start += 1                        # Don't include ':'
            str_length = str.size - str_start - 1 # -1 for the null byte
            cur = 0                               # Simulate end of string
          else
            read_until ' '
            str_length = pos - str_start
          end
          params << String.new str[str_start, str_length]
          break if cur == 0
          incr
        end
        @params = params
      end
    rescue
      raise ParseError.new(String.new(@str))
    end

    private def parse_tags
      if pos = @tags_start
        str = @str

        cur = str[pos]

        tags = {} of String => String | Nil
        while true
          # At start of ircv3 tag
          key_start = pos
          read_until ';', '=', ' '
          key = String.new str[key_start, pos - key_start]

          if cur == '='.ord
            incr # Skip '='

            part_start = pos
            read_until ';', ' ', '\\'
            part_length = pos - part_start

            if cur == '\\'.ord
              # Enter escaped parsing mode
              value = String::Builder.build do |b|
                b.write(str[part_start, part_length]) # Write what was before the first escape
                incr

                while true
                  case cur
                  when ':'.ord
                    b.write_byte ';'.ord.to_u8
                  when 's'.ord
                    b.write_byte ' '.ord.to_u8
                  when '\\'.ord
                    b.write_byte '\\'.ord.to_u8
                  when 'r'.ord
                    b.write_byte '\r'.ord.to_u8
                  when 'n'.ord
                    b.write_byte '\n'.ord.to_u8
                  end
                  incr

                  part_start = pos
                  read_until ';', ' ', '\\'
                  part_length = pos - part_start
                  b.write(str[part_start, part_length])

                  break if cur == ';'.ord || cur == ' '.ord # Finish string building

                  # We are cur == '\\'
                  incr
                end
              end
            else
              value = String.new str[part_start, part_length]
            end
          else
            value = nil
          end # End value parsing

          tags[key] = value

          # We must be on ';' or ' '
          break if cur == ' '.ord

          incr # Skip ';'
        end
        @tags = tags
      end
    rescue
      raise ParseError.new(String.new(@str))
    end
  end

  struct Prefix
    include ParserHelpers

    # Parses an IRC Prefix from a Slice(UInt8).
    # The slice should not have trailing \r\n characters and should be null terminated.
    def self.parse(str : Slice(UInt8))
      raise "IRC message is not null terminated" if str[-1] != 0
      pos = 0
      cur = str[pos]

      prefix = nil

      parse_prefix

      prefix
    rescue ex
      raise ParseError.new(String.new(str))
    end

    # Parses an IRC Prefix from a String.
    # The String should not have the trailing "\r\n" characters.
    def self.parse(str)
      parse Slice.new(str.to_unsafe, str.bytesize + 1)
    end
  end
end
