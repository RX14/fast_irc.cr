module FastIRC
  struct Prefix
    getter! target : String?
    getter! user : String?
    getter! host : String?

    def initialize(@target = nil, @user = nil, @host = nil)
    end

    # Converts the prefix back into an IRC format string. (e.g. "nick!user@host" )
    def to_s(io)
      if target = @target
        io << target

        if user = @user
          io << '!'
          io << user
        end

        if host = @host
          io << '@'
          io << host
        end
      else
        io << @host
      end
    end
  end
end
