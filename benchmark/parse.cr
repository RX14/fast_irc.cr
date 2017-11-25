require "../src/fast_irc"

def run(io, target_time, parse_rate = 200)
  # At an assumed 200MiB/s parsing rate, 1MiB will take 5ms to parse, meaning we
  # should perform 200 iterations per megabyte for each second of test time we want.
  io_megabytes = io.bytesize.to_f / (1024 * 1024)
  test_cycles = (parse_rate * target_time.total_seconds / io_megabytes).to_i

  ts = Time.measure do
    test_cycles.times do
      io.rewind
      FastIRC.parse(io) { }
    end
  end

  puts "  Parsed #{test_cycles} times in #{ts.total_seconds.round(2)}s"
  puts "  #{(io_megabytes * test_cycles / ts.total_seconds).round(2)}MiB/s"
  puts "  #{(io_megabytes * 8 * test_cycles / ts.total_seconds).round(2)}mbps"

  io_megabytes * test_cycles / ts.total_seconds
end

input_filename = ARGV[0]
io = IO::Memory.new(File.read(input_filename).gsub({"\r": "\r\n", "\n": "\r\n"}))

io_megabytes = io.bytesize.to_f / (1024 * 1024)
puts "Input is #{io_megabytes.round(3)}MiB"

puts "Warmup:"
parse_rate = run(io, 5.seconds)
puts "Run:"
run(io, 30.seconds, parse_rate)
