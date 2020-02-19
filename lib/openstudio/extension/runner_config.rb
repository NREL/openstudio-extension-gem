# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2020, Alliance for Sustainable Energy, LLC.
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER(S) AND ANY CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER(S), ANY CONTRIBUTORS, THE
# UNITED STATES GOVERNMENT, OR THE UNITED STATES DEPARTMENT OF ENERGY, NOR ANY OF
# THEIR EMPLOYEES, BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
# OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# *******************************************************************************

require 'json'

module OpenStudio
  module Extension
    class RunnerConfig
      FILENAME = 'runner.conf'.freeze

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

      ##
      # Return the default runner configuration
      def self.default_config
        return {
          file_version: '0.1.0',
          max_datapoints: 1E9.to_i,
          num_parallel: 2,
          run_simulations: true,
          verbose: false
        }
      end

      ##
      # Save a templated runner configuration to the specified directory. Note that this will override any
      # config that has been created
      #
      #  @param [String] dirname Directory where runner.conf file is stored, typically the root of the extension.
      def self.init(dirname)
        File.open(File.join(dirname, FILENAME), 'w') do |f|
          f << JSON.pretty_generate(default_config)
        end

        return default_config
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
        if @data.has_key? key.to_sym
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
