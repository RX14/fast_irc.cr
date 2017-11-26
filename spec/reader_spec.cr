require "./spec_helper"

describe FastIRC::Reader do
  context "reads messages" do
    it do
      io = IO::Memory.new("ABC 123\n" * (8192 / 8))
      FastIRC.parse(io) do |msg|
        msg.command.should eq("ABC")
        msg.params.should eq(["123"])
      end
    end

    it do
      io = IO::Memory.new("ABC 12\r\n" * (8192 / 8))
      FastIRC.parse(io) do |msg|
        msg.command.should eq("ABC")
        msg.params.should eq(["12"])
      end
    end

    it do
      io = IO::Memory.new
      io << "ABC 12\r\n" * ((8192 / 8) - 1)
      # This makes sure that there's a \r\n split in the buffer boundary
      io << "ABC :12\r\n"
      io.rewind
      FastIRC.parse(io) do |msg|
        msg.command.should eq("ABC")
        msg.params.should eq(["12"])
      end
    end
  end
end
