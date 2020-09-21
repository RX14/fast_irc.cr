module FastIRC
  # An IRC message containing command, parameters, prefix and IRCv3 tags.
  #
  # To parse a line of IRC, see `FastIRC.parse` or `FastIRC.parse_line`.
  struct Message
    @tags : Tags?
    # See `Prefix`
    getter prefix : Prefix?
    getter command : String
    @params : Array(String)?

    def params
      @params ||= Array(String).new
    end

    def params?
      @params
    end

    # IRCv3 tags
    def tags
      @tags ||= Tags.new
    end

    # ditto
    def tags?
      @tags
    end

    # ```
    # m = FastIRC::Message.new("PRIVMSG", ["#WAMM", "testing message"])
    # m.to_s # => "PRIVMSG #WAMM :testing message\r\n"
    # ```
    def initialize(@command, @params, *, @prefix = nil, @tags = nil)
    end

    def inspect(io)
      io << "Message(@tags=#{@tags.inspect}, @prefix=#{@prefix.inspect}, @command=#{@command.inspect}, @params=#{@params.inspect})"
    end

    # Converts the message back into a raw IRC message, including trailing "\r\n".
    def to_s(io)
      if tags = @tags
        io << '@'
        tags.join(io, ';') do |(key, value)|
          io << key

          if value
            io << '='
            value.each_char do |char|
              case char
              when ';'
                io << %q(\:)
              when ' '
                io << %q(\s)
              when '\\'
                io << %q(\\)
              when '\r'
                io << %q(\r)
              when '\n'
                io << %q(\n)
              else
                io << char
              end
            end
          end
        end
        io << ' '
      end

      if prefix = @prefix
        io << ':'
        io << prefix
        io << ' '
      end

      io << @command

      if params = @params
        params.each_with_index do |param, param_idx|
          io << ' '

          trailing = validate_param(param, last: param_idx == params.size - 1)

          io << ':' if trailing
          io << param
        end
      end

      io << "\r\n"
    end

    @[AlwaysInline]
    private def validate_param(param, last)
      trailing = false

      if param.empty?
        if last
          trailing = true
        else
          raise "Non-trailing parameter cannot be empty while serialising #{inspect}"
        end
      end

      param.each_char_with_index do |char, char_idx|
        if char == '\0' || char == '\r' || char == '\n'
          raise "Parameter cannot include '\\0', '\\r' or '\\n' while serialising #{inspect}"
        end

        if (char_idx == 0 && char == ':') || char == ' '
          if last
            trailing = true
          else
            raise "Non-trailing parameter cannot start with ':' or contain ' ' while serialising #{inspect}"
          end
        end
      end

      trailing
    end
  end

  # Prefix of the IRC message (nick!user@host).
  #
  # IRC Prefixes can either consist of a nickname with optional user and host,
  # or a server hostname. To handle both these cases, `source` is set to either
  # the nick or server name depending on which type of prefix is received. This
  # means `source` is always present.
  struct Prefix
    getter source : String
    getter user : String?
    getter host : String?

    def initialize(*, @source, @user, @host)
    end

    # Returns true if the source of this prefix an IRC server.
    #
    # The check used for the is if the source contains a '.' character.
    def server?
      source.includes?('.')
    end

    # Returns true if the source of this prefix an IRC server.
    #
    # The same as `!server?`.
    def user?
      !server?
    end

    def inspect(io)
      io << "Prefix(@source=#{@source.inspect}, @user=#{@user.inspect}, @host=#{@host.inspect})"
    end

    # Converts the prefix back into a raw IRC prefix (e.g. nick!user@host). Does
    # not include leading ':'.
    def to_s(io)
      io << source

      if user = @user
        io << '!'
        io << user
      end

      if host = @host
        io << '@'
        io << host
      end
    end
  end
end
