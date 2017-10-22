require "./fast_irc/*"

module FastIRC
  VERSION = "0.3.1"

  alias Tags = Hash(String, String?)

  # Parses a stream of IRC messages arriving on *io*, yielding each message
  # object.
  #
  # See `Reader`.
  def self.parse(io)
    reader = FastIRC::Reader.new(io)
    while message = reader.next
      yield message
    end
  end
end
