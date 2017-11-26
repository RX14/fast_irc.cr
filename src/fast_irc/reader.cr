module FastIRC
  # Reads an `IO` stream and outputs a stream of `Message` objects.
  #
  # TODO: use a circular buffer to reduce memory copies?
  class Reader
    # Working memory allocated for storing IRC data
    @buffer_memory : Slice(UInt8)
    # Valid area of @buffer_memory
    @buffer : Slice(UInt8)

    # Creates a new `Reader` which reads from *io*. When *strict* is set, it
    # will be passed to `FastIRC.parse_line`.
    def initialize(@io : IO, @strict = false)
      @buffer_memory = Slice(UInt8).new(8192)
      @buffer = @buffer_memory[0, 0]
      @eof = false
    end

    # Reads the next IRC message from the IO, or returns nil on EOF.
    #
    # ```
    # irc_reader = FastIRC::Reader.new(io)
    # while message = irc_reader.next
    #   message.command # => "PRIVMSG" : String
    # end
    # ```
    def next : Message?
      line = Bytes.empty
      while line.empty?
        return nil if @eof

        until index = @buffer.index('\n'.ord.to_u8)
          read_size = fill_buffer
          if read_size == 0
            @eof = true
            index = @buffer.size
            break
          end
        end

        index = index.not_nil!

        line = @buffer[0, index]
        @buffer += {index + 1, @buffer.size}.min

        line = line[0, line.size - 1] if line.size > 0 && line[-1] == '\r'.ord
      end

      FastIRC.parse_line(line, strict: @strict)
    end

    @[AlwaysInline]
    private def fill_buffer
      # Move remaining buffer contents to start of buffer memory
      @buffer.move_to @buffer_memory

      # Calculate slice which we can read into
      read_slice = @buffer_memory + @buffer.size
      raise ParseException.new("Line length longer than 8192 chars") if read_slice.size == 0

      # Read from IO into slice
      read_size = @io.read(read_slice)

      # Calculate new valid buffer
      @buffer = @buffer_memory[0, @buffer.size + read_size]

      read_size
    end
  end
end
