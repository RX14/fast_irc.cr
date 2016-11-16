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
      # If the buffer is empty, we need to fill the buffer.
      if @buffer.size == 0
        read_size = fill_buffer
        # If we read 0 bytes, we have reached EOF.
        return nil if read_size == 0
      end

      # Keep calling fill_buffer and find_line_size until we read a line. We
      # also store start_index, which is the index of the byte to start scanning
      # for line endings at. If find_line_size doesn't find an ending, this is
      # always `@buffer.size` because of the condition on the while loop.
      line_size, line_with_crlf_size = find_line_size
      start_index = @buffer.size
      while line_with_crlf_size == -1
        read_size = fill_buffer

        if read_size == 0
          # If we read 0 bytes, we have reached EOF. Assume that we have an
          # IRC message in the remainder of the buffer.
          message = FastIRC.parse_line(@buffer, strict: @strict)
          @buffer += @buffer.size
          return message
        end

        line_size, line_with_crlf_size = find_line_size(start_index)
        start_index = @buffer.size
      end

      # We have a line, parse it and increment buffer.
      message = FastIRC.parse_line(@buffer[0, line_size], strict: @strict)
      @buffer += line_with_crlf_size
      message
    end

    # Returns {line_size, line_with_crlf_size}
    @[AlwaysInline]
    private def find_line_size(start_index = 0)
      i = start_index
      max_size = {@buffer.size, 1024}.min # IRCv3 max message size

      while i < max_size
        byte = @buffer[i]
        if byte == '\r'.ord
          if (i + 1 < max_size) && @buffer[i + 1] == '\n'.ord
            return {i, i + 2}
          else
            return {i, i + 1}
          end
        end

        if byte == '\n'.ord
          return {i, i + 1}
        end

        i += 1
      end

      {-1, -1}
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
