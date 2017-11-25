require "../src/fast_irc"

def run(messages, target_time, serialize_rate = 325)
  output = IO::Memory.new

  # At an assumed 200MiB/s serialization rate, 1MiB will take 5ms to parse, meaning we
  # should perform 200 iterations per megabyte for each second of test time we want.
  messages.each do |message|
    message.to_s(output)
  end
  output_megabytes = output.bytesize.to_f / (1024 * 1024)
  test_cycles = (serialize_rate * target_time.total_seconds / output_megabytes).to_i

  ts = Time.measure do
    test_cycles.times do
      output.rewind
      messages.each do |message|
        message.to_s(output)
        output << "\r\n"
      end
    end
  end

  puts "  Serialized #{test_cycles} times in #{ts.total_seconds.round(2)}s"
  puts "  #{(output_megabytes * test_cycles / ts.total_seconds).round(2)}MiB/s"
  puts "  #{(output_megabytes * 8 * test_cycles / ts.total_seconds).round(2)}mbps"

  output_megabytes * test_cycles / ts.total_seconds
end

input_filename = ARGV[0]

messages = Array(FastIRC::Message).new
File.open(input_filename) do |file|
  puts "Input size is  #{(file.size.to_f / (1024 * 1024)).round(3)}MiB"
  FastIRC.parse(file) do |message|
    messages << message
  end
end

output = IO::Memory.new
messages.each do |message|
  message.to_s(output)
end
output_megabytes = output.bytesize.to_f / (1024 * 1024)
puts "Output size is #{output_megabytes.round(3)}MiB"

puts "Warmup:"
parse_rate = run(messages, 5.seconds)
puts "Run:"
run(messages, 30.seconds, parse_rate)
