module FastIRC
  class ParseError < Exception
    def initialize(message : String)
      super("Failed to parse IRC message #{message.inspect}")
    end
  end

  # :nodoc:
  module ParserMacros # https://github.com/manastech/crystal/issues/1265
    macro incr
            pos += 1
            cur = str[pos]
        end

    macro incr_while(expr)
            while {{expr}} && cur != 0
                incr
            end
        end

    macro parse_prefix
            target_start = pos
            incr_while cur != ' '.ord && cur != '!'.ord && cur != '@'.ord && cur != '.'.ord
            if cur == '.'.ord
                is_host = true
                incr_while cur != ' '.ord && cur != '!'.ord && cur != '@'.ord
            end
            target_length = pos - target_start

            if is_host
                host_start = target_start
                host_length = target_length
                target_start = nil
                target_length = nil
            end

            if cur == '!'.ord
                incr

                user_start = pos
                incr_while cur != '@'.ord && cur != ' '.ord
                user_length = pos - user_start
            end

            if cur == '@'.ord
                incr

                host_start = pos
                incr_while cur != ' '.ord
                host_length = pos - host_start
            end

            prefix = Prefix.new(str, target_start, target_length, user_start, user_length, host_start, host_length)
        end
  end

  struct Message
    include ParserMacros

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
        incr_while cur != ' '.ord

        incr
      end

      if cur == ':'.ord
        incr

        parse_prefix

        incr
      end

      command_start = pos
      incr_while cur != ' '.ord
      command = String.new str[command_start, pos - command_start]

      unless cur == 0
        incr

        params_start = pos
      end
      Message.new(str, tags_start, prefix, command.not_nil!, params_start)
    rescue
      raise ParseError.new(String.new(str))
    end

    # Parses an IRC message from a String.
    # The String should not have the trailing "\r\n" characters.
    def self.parse(str)
      parse Slice.new(str.to_unsafe, str.bytesize + 1)
    end

    # The parameters of the IRC message as an Array(String), or nil if there were none.
    def params?
      unless @params
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
              incr_while cur != ' '.ord
              str_length = pos - str_start
            end
            params << String.new str[str_start, str_length]
            break if cur == 0
            incr
          end
          @params = params
        end
      end
      @params
    rescue
      raise ParseError.new(String.new(@str))
    end

    # The parameters of the IRC message as an Array(String), or an empty array if there were none.
    # For faster performance with 0 parameter messages, use `params?`.
    def params
      params? || [] of String
    end

    # The IRCv3 tags of the IRC message as a Hash(String, String|Nil), or nil if there were none.
    # Tags with no value are mapped to nil.
    def tags?
      unless @tags
        if pos = @tags_start
          str = @str

          cur = str[pos]

          tags = {} of String => String | Nil
          while true
            # At start of ircv3 tag
            key_start = pos
            incr_while cur != ';'.ord && cur != '='.ord && cur != ' '.ord
            key = String.new str[key_start, pos - key_start]

            if cur == '='.ord
              incr # Skip '='

              part_start = pos
              incr_while cur != ';'.ord && cur != ' '.ord && cur != '\\'.ord
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
                    incr_while cur != ';'.ord && cur != ' '.ord && cur != '\\'.ord
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
      end
      @tags
    rescue
      raise ParseError.new(String.new(@str))
    end

    # The IRCv3 tags of the IRC message as a Hash(String, String|Nil), or an empty Hash if there were none.
    # Tags with no value are mapped to nil.
    # For faster performance when there are no tags, use `tags?`
    def tags
      tags? || {} of String => String | Nil
    end
  end

  struct Prefix
    include ParserMacros

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
