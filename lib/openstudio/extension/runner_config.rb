# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# Check if Bundler is already loaded
if !defined?(Bundler)
  require 'bundler'
end
require 'fileutils'
require 'json'
require 'parallel'

module OpenStudio
  module Extension
    class RunnerConfig
      FILENAME = 'runner.conf'.freeze

      DEFAULT_NPROC = Parallel.processor_count - 1

      ##
      # Class to store configuration of the runner options.
      ##
      #  @param [String] dirname Directory where runner.conf file is stored, typically the root of the extension.
      def initialize(dirname)
        # read in the runner config from file, if it exists, otherwise inform the user to run
        # the rake task
        @dirname = dirname

        check_file = File.join(@dirname, FILENAME)
        if File.exist? check_file
          @data = JSON.parse(File.read(check_file), symbolize_names: true)
        else
          raise "There is no runner.conf in directory #{@dirname}. Run `rake openstudio:runner:init`"
        end
      end

      ##
      # Add runner configuration that may be used in other extensions
      #
      #  @param [String] name, Name of the new config option
      def add_config_option(name, value)
        if @data.key? name.to_sym
          raise "Runner config already has the named option of #{name}"
        end

        # TODO: do we need to verify that name is allowed to be a key?
        @data[name.to_sym] = value
      end

      def self.get_local_bundle_config_path(dirname)
        # Bundler.settings reads from pwd, and I can't test with this...
        bundler_settings = Bundler::Settings.new(File.join(dirname, '.bundle'))

        if (bundle_install_path = bundler_settings.path.explicit_path)
          puts "Defaulting bundle_install_path to bundle's local config value: '#{bundle_install_path}'"
        else
          puts "Defaulting to .bundle/install (and ignoring system wide: Bundler.configured_bundle_path.base_path=#{bundler_settings.path.base_path})"
          bundle_install_path = File.join(dirname, '.bundle/install/')
        end

        return bundle_install_path
      end

      ##
      # Return the default runner configuration
      def self.default_config(dirname)
        return {
          file_version: '0.1.0',
          max_datapoints: 1E9.to_i,
          num_parallel: DEFAULT_NPROC,
          run_simulations: true,
          verbose: false,
          gemfile_path: '',
          bundle_install_path: get_local_bundle_config_path(dirname),
        }
      end

      ##
      # Save a templated runner configuration to the specified directory. Note that this will override any
      # config that has been created
      #
      #  @param [String] dirname Directory where runner.conf file is stored, typically the root of the extension.
      def self.init(dirname)
        runner_conf_file = File.join(dirname, FILENAME)
        if File.exist?(runner_conf_file)
          puts "runner.conf already exists, saving a runner.conf.bak, previous config:"
          puts File.read(runner_conf_file)
          FileUtils.cp(runner_conf_file, "#{FILENAME}.bak")
        end

        config = default_config(dirname)
        File.open(runner_conf_file, 'w') do |f|
          f << JSON.pretty_generate(config)
        end

        return config
      end

      ##
      # Save the updated config options, if they have changed. Changes will typically only occur if calling add_config
      # option
      def save
        File.open(File.join(@dirname, FILENAME), 'w') do |f|
          f << JSON.pretty_generate(@data)
        end
      end

      ##
      # Update a runner config value
      #
      # @param [String] key, The name of the key to update
      # @param [Variant] new_value, The new value to set the `key` to.
      def update_config(key, new_value)
        if @data.key? key.to_sym
          @data[key.to_sym] = new_value
        else
          raise "Could not find key '#{key}' to update in RunnerConfig."
        end
      end

      ##
      # Return the options as hash
      def options
        return @data
      end
    end
  end
end
