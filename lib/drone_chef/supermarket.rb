require 'pathname'
require 'fileutils'

module DroneChef
  #
  # Class for uploading stuff to a Supermarket
  #
  class Supermarket
    def initialize(config)
      @config = config
      verify_reqs
    end

    def upload # rubocop:disable AbcSize
      puts "Checking if #{cookbook.name}@#{cookbook.version} " \
           "is already shared to #{@config.server}"
      puts "Cookbook #{cookbook.name} version #{cookbook.version} " \
           "already uploaded to #{@config.server}" if uploaded?
      return if uploaded?
      fail 'Failed to upload cookbook' unless upload_command
    end

    def write_configs
      @config.write_configs
      write_knife_rb
    end

    private

    def verify_reqs
      fail 'Missing cookbook metadata.rb' unless File.exist? "#{@config.workspace}/metadata.rb"
      fail 'Missing cookbook README.md' unless File.exist? "#{@config.workspace}/README.md"
    end

    def write_knife_rb # rubocop:disable AbcSize
      FileUtils.mkdir_p File.dirname @config.knife_rb
      File.open(@config.knife_rb, 'w') do |f|
        f.puts "node_name '#{@config.user}'"
        f.puts "client_key '#{@config.key_path}'"
        f.puts "cookbook_path '#{Pathname.new(@config.workspace).parent}'"
        f.puts "ssl_verify_mode #{@config.ssl_verify_mode}"
        f.puts "knife[:supermarket_site] = '#{@config.server}'"
      end
    end

    def process_last_status
      $?
    end

    def cookbook
      @metadata ||= begin
        metadata = Chef::Cookbook::Metadata.new
        metadata.from_file("#{@config.workspace}/metadata.rb")
        metadata
      end
    end

    def upload_command
      command = ["knife supermarket share #{cookbook.name}"]
      command << "-c #{@config.knife_rb}"
      puts `#{command.join(' ')}`
      process_last_status.success?
    end

    def uploaded?
      knife_show
    end

    def knife_show
      @cookbook_uploaded ||= begin
        command = ["knife supermarket show #{cookbook.name} #{cookbook.version}"]
        command << "-c #{@config.knife_rb}"
        `#{command.join(' ')}`
        process_last_status.success?
      end
    end
  end
end
