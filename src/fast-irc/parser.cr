module FastIrc
    struct Message
        macro incr
            pos += 1
            cur = str[pos]
        end

        macro incr_while(expr)
            while {{expr}} && cur != 0
                incr
            end
        end

        def self.parse(str : Slice(UInt8))
            raise "IRC message is not null terminated" if str[-1] != 0
            pos = 0
            cur = str[pos]

            if cur == ':'.ord
                incr
                
                target_start = pos
                incr_while cur != ' '.ord && cur != '!'.ord && cur != '@'.ord
                target_length = pos - target_start

                if cur == '!'.ord
                    incr

                    user_start = pos
                    incr_while cur != '@'.ord
                    user_length = pos - user_start
                end

                if cur == '@'.ord
                    incr

                    host_start = pos
                    incr_while cur != ' '.ord
                    host_length = pos - host_start
                end

                prefix = Prefix.new(str, target_start, target_length, user_start, user_length, host_start, host_length)
                incr
            end

            command_start = pos
            incr_while cur != ' '.ord
            command = String.new str[command_start, pos - command_start]

            unless cur == 0
                incr
                
                params_start = pos
            end
            
            Message.new(str, prefix, command, params_start)
        end

        def self.parse(str)
            parse Slice.new(str.cstr, str.bytesize + 1)
        end

        def params
            unless @params
                params = [] of String
                if pos = @params_start
                    str = @str

                    cur = str[pos]

                    while true
                        str_start = pos
                        if cur == ':'.ord
                            str_start += 1
                            incr_while true
                        else
                            incr_while cur != ' '.ord
                        end
                        params << String.new str[str_start, pos - str_start]
                        break if cur == 0
                        incr
                    end
                end
                @params = params
            end
            @params
        end
    end
end
