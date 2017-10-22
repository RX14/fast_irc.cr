require "./spec_helper"
require "yaml"

describe FastIRC do
  describe "VERSION" do
    it "matches shards.yml" do
      version = YAML.parse(File.read(File.join(__DIR__, "..", "shard.yml")))["version"].as_s
      version.should eq(FastIRC::VERSION)
    end

    it "matches the README" do
      version = YAML.parse(File.read(File.join(__DIR__, "..", "shard.yml")))["version"].as_s
      readme_line = File.read(File.join(__DIR__, "..", "README.md")).lines[21]

      readme_line.should contain(version)
    end
  end
end
