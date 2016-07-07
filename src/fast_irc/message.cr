private macro slice_getter(name)
    def {{name.id}}?
        unless @{{name.id}}
            if ({{name.id}}_start = @{{name.id}}_start) && ({{name.id}}_length = @{{name.id}}_length)
                @{{name.id}} = String.new @str[{{name.id}}_start, {{name.id}}_length]
            end
        end
        @{{name.id}}
    end

    def {{name.id}}
        {{name.id}}?.not_nil!
    end

    @{{name.id}}_start : Int32?
    @{{name.id}}_length : Int32?
    @{{name.id}} : String?
end

module FastIRC
  struct Prefix
    slice_getter target
    slice_getter user
    slice_getter host

    def_equals target?, user?, host?

    # Initialises the Prefix with a backing Slice(UInt8) of bytes, and the locations of strings inside the slice.
    # Use this method only if you know what you are doing.
    def initialize(@str : Slice(UInt8), @target_start, @target_length, @user_start, @user_length, @host_start, @host_length)
    end

    # Initialises the Prefix with the given target, user and host strings.
    def initialize(@target, @user = nil, @host = nil)
      @str = Slice(UInt8).new(0)
    end

    def inspect(io)
      io << "Prefix(@target=#{target?.inspect}, @user=#{user?.inspect}, @host=#{host?.inspect})"
    end

    # Converts the prefix back into an IRC format string. (e.g. "nick!user@host" )
    def to_s(io)
      if target = self.target?
        io << target
      end

      if user = self.user?
        io << '!'
        io << user
      end

      if host = self.host?
        io << '@' if user? || target?
        io << host
      end
    end
  end

  struct Message
    include ParserMacros

    getter! prefix
    getter command

    def_equals prefix?, command, params?, tags?

    @params : Array(String)?
    @tags : Hash(String, String?)?

    # Initialises the Message with a backing Slice(UInt8) of bytes, and the locations of strings inside the slice.
    # Use this method only if you know what you are doing.
    def initialize(@str : Slice(UInt8), @tags_start : Int32?, @prefix : Prefix?, @command : String, @params_start : Int32?)
    end

    # Initialises the Message with the given tags, prefix, command and params.
    def initialize(@command, @params = nil, @prefix = nil, @tags : Hash(String, String?)? = nil)
      @str = Slice(UInt8).new(0)
      @tags_start = nil
      @params_start = nil
    end

    def inspect(io)
      io << "Message(@tags=#{tags?.inspect}, @prefix=#{prefix?.inspect}, @command=#{command.inspect}, @params=#{params?.inspect})"
    end

    # Converts the Message back into an IRC format string. (e.g. "@tag :nick!user@host COMMAND arg1 :more args" )
    def to_s(io)
      if tags = self.tags?
        io << '@'
        first = true
        tags.each do |key, value|
          unless first
            io << ';'
          end
          first = false

          io << key

          if value
            io << '='

            str = Slice.new(value.to_unsafe, value.bytesize + 1)
            pos = 0

            cur = str[pos]

            while true
              part_start = pos
              incr_while cur != ';'.ord && cur != ' '.ord && cur != '\\'.ord && cur != '\r'.ord && cur != '\n'.ord
              io << String.new str[part_start, pos - part_start]

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

      if prefix = self.prefix?
        io << ':'
        prefix.to_s io
        io << ' '
      end

      io << command

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
