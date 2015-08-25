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
end

module FastIRC
    struct Prefix
        slice_getter target
        slice_getter user
        slice_getter host

        def_equals target?, user?, host?

        def initialize(@str : Slice(UInt8), @target_start, @target_length, @user_start, @user_length, @host_start, @host_length)
        end

        def initialize(@target, @user, @host)
            @str = Slice(UInt8).new(0)
        end

        def inspect(io)
            io << "Prefix(@target=#{target?.inspect}, @user=#{user?.inspect}, @host=#{host?.inspect})"
        end

        def to_s(io)

            io << @target

            if user = @user
                io << '!'
                io << user
            end

            if host = @host
                io << '@' if @user || @target
                io << host
            end
        end
    end

    struct Message
        include ParserMacros

        getter! prefix
        getter command

        def_equals prefix?, command, params?, tags?

        def initialize(@str : Slice(UInt8), @tags_start, @prefix, @command, @params_start)
          @params = nil
        end

        def initialize(@tags, @prefix, @command, @params)
            @str = Slice(UInt8).new(0)
        end

        def inspect(io)
            io << "Message(@tags=#{tags?.inspect}, @prefix=#{prefix?.inspect}, @command=#{command.inspect}, @params=#{params?.inspect})"
        end

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

                        str = Slice.new(value.cstr, value.bytesize + 1)
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
                io << prefix
                io << ' '
            end

            io << command

            if params = self.params?
                params.each do |param|
                    io << ' '
                    if param.empty? || param.starts_with?(':') || param.includes? ' '
                        io << ':'
                    end
                    io << param
                end
            end
        end
    end
end
