module FastIrc
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
        end
    end

    struct Message
        include ParserMacros

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
        end

        def self.parse(str)
            parse Slice.new(str.cstr, str.bytesize + 1)
        end

        def params
            unless @params
                if pos = @params_start
                    str = @str

                    cur = str[pos]

                    params = [] of String
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

        def tags
            unless @tags
                if pos = @tags_start
                    str = @str

                    cur = str[pos]

                    tags = {} of String => String|Nil
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
                                    b.write(str + part_start, part_length) # Write what was before the first escape
                                    incr

                                    while true
                                        puts "ESCAPE SWITCH: #{cur.chr}"
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
                                        b.write(str + part_start, part_length)

                                        puts "BN: '#{cur.chr}' #{cur == ';'.ord || cur == ' '.ord}"
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
                end
                @tags = tags
            end
            @tags
        end
    end

    struct Prefix
        include ParserMacros

        def self.parse(str : Slice(UInt8))
            raise "IRC message is not null terminated" if str[-1] != 0
            pos = 0
            cur = str[pos]

            prefix = nil

            parse_prefix

            prefix
        end

        def self.parse(str)
            parse Slice.new(str.cstr, str.bytesize + 1)
        end
    end
end
