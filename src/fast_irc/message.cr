module FastIRC
  class Message
    getter! prefix : Prefix?
    getter command : String

    @params : Array(String)?
      @tags : Hash(String, String | Nil)?

    def initialize(@command, @params = nil, @prefix = nil, @tags = nil)
      @str = Slice(UInt8).new(0)
    end

    def_equals prefix?, command, params?, tags?

    # The parameters of the IRC message as an Array(String), or an empty array if there were none.
    # For faster performance with 0 parameter messages, use `params?`.
    def params
      params? || [] of String
    end

    # The parameters of the IRC message as an Array(String), or nil if there were none.
    def params?
      parse_params unless @params
      @params
    end

    # The IRCv3 tags of the IRC message as a Hash(String, String|Nil), or an empty Hash if there were none.
    # Tags with no value are mapped to nil.
    # For faster performance when there are no tags, use `tags?`
    def tags
      tags? || {} of String => String | Nil
    end

    # The IRCv3 tags of the IRC message as a Hash(String, String|Nil), or nil if there were none.
    # Tags with no value are mapped to nil.
    def tags?
      parse_tags unless @tags
      @tags
    end

    # Converts the Message back into an IRC format string. (e.g. "@tag :nick!user@host COMMAND arg1 :more args" )
    def to_s(io)
      if tags = self.tags?
        io << '@'
        first = true
        tags.each do |key, value|
          io << ';' unless first
          first = false

          io << key

          if value
            io << '='

            str = Slice.new(value.to_unsafe, value.bytesize + 1)
            pos = 0

            cur = str[pos]

            while true
              part_start = pos
              read_until ';', ' ', '\\', '\r', '\n'
              io.write str[part_start, pos - part_start]

              case cur
              when 0
                break
              when ';'.ord
                io << "\\:"
              when ' '.ord
                io << "\\s"
              when '\\'.ord
                io << "\\\\"
              when '\r'.ord
                io << "\\r"
              when '\n'.ord
                io << "\\n"
              end
              incr
            end
          end
        end
        io << ' '
      end

      if prefix = @prefix
        io << ':'
        prefix.to_s io
        io << ' '
      end

      io << @command

      if params = self.params?
        params.each_with_index do |param, param_idx|
          io << ' '

          trailing = false
          param.each_char_with_index do |char, char_idx|
            if char == '\0' || char == '\r' || char == '\n'
              raise "Parameter cannot include '\\0', '\\r' or '\\n' while serialising #{inspect}"
            end

            if (char_idx == 0 && char == ':') || char == ' '
              if param_idx == params.size - 1
                trailing = true
              else
                raise "Non-trailing parameter cannot start with ':' or contain ' ' while serialising #{inspect}"
              end
            end
          end

          if param.empty?
            if param_idx == params.size - 1
              trailing = true
            else
              raise "Non-trailing parameter cannot be empty while serialising #{inspect}"
            end
          end

          io << ':' if trailing
          io << param
        end
      end
    end
  end
end
