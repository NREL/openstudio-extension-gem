# frozen_string_literal: true

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

require 'openstudio/extension/version'
require 'openstudio/extension/runner'
require 'openstudio/extension/runner_config'

module OpenStudio
  module Extension
    class Extension
      attr_accessor :root_dir

      # Typically one does not pass in the root path and it is defaulted as the root path of the project
      # that is inheriting the extension. The root path can be overriden as needed on initialization only. This
      # is mainly used for testing purposes.
      # @param root_dir: string, fully qualified path of the root directory of the extension gem.
      def initialize(root_dir = nil)
        @root_dir = root_dir || File.absolute_path(File.join(File.dirname(__FILE__), '..', '..'))
      end

      # Return the absolute path of the measures or nil if there is none, used when configuring OSWs
      def measures_dir
        return File.absolute_path(File.join(@root_dir, 'lib', 'measures'))
      end

      # Relevant files such as weather data, design days, etc.
      # Return the absolute path of the files or nil if there is none, used when configuring OSWs
      def files_dir
        return File.absolute_path(File.join(@root_dir, 'lib', 'files'))
      end

      # Doc templates are common files like copyright files which are used to update measures and other code
      # Doc templates will only be applied to measures in the current repository
      # Return the absolute path of the doc templates dir or nil if there is none
      def doc_templates_dir
        return File.absolute_path(File.join(@root_dir, 'doc_templates'))
      end

      # Do not override
      # Files in the core directory are copied into measure resource folders to build standalone measures
      # Files will be copied into the resources folder of measures which have files of the same name
      # Return the absolute path of the core dir or nil if there is none
      def core_dir
        return File.absolute_path(File.join(@root_dir, 'lib', 'openstudio', 'extension', 'core'))
      end
    end

    ##
    # Module method to return all classes derived from OpenStudio::Extension::Extension
    # Note all extension classes must be loaded before calling this method
    ##
    #  @return [Array]: Array of classes
    def self.all_extensions
      # DLM: consider calling Bundler.require in this method
      # do not call Bundler.require when requiring this file, only when calling this method
      result = []
      ObjectSpace.each_object(::Class) do |obj|
        next if !obj.ancestors.include?(OpenStudio::Extension::Extension)

        result << obj
      end
      return result.uniq
    end

    ##
    # Module method to return measure directories from all extensions
    ##
    #  @return [Array]: Array of measure directories
    def self.all_measure_dirs
      result = []
      all_extensions.each do |obj|
        dir = obj.new.measures_dir
        result << dir if dir
      rescue StandardError
      end
      return result.uniq
    end

    ##
    # Module method to return file directories from all extensions
    ##
    #  @return [Array]  Array of measure resource directories
    def self.all_file_dirs
      result = []
      all_extensions.each do |obj|
        dir = obj.new.files_dir
        result << dir if dir
      rescue StandardError
      end
      return result.uniq
    end

    ##
    # Module method to check for duplicate file, measure, or measure resource names across all extensions
    #
    # Will raise an error if conflicting file names are found.
    # Note that file names in measure_files_dir names (e.g. License.md) are expected to be the same across all extensions.
    ##
    def self.check_for_name_conflicts
      measure_dirs = all_measure_dirs
      file_dirs = all_file_dirs
      conflicts = []

      measure_dir_names = {}
      measure_dirs.each do |dir|
        Dir.glob(File.join(dir, '*')).each do |file|
          next if !File.directory?(file)
          next if !File.exist?(File.join(file, 'measure.rb'))

          # puts file
          file_name = File.basename(file).downcase
          if measure_dir_names[file_name]
            conflicts << "Measure '#{file}' conflicts with '#{measure_dir_names[file_name]}'"
          else
            measure_dir_names[file_name] = file
          end
        end
      end

      file_names = {}
      file_dirs.each do |dir|
        Dir.glob(File.join(dir, '*')).each do |file|
          next if !File.file?(file)

          # puts file
          file_name = File.basename(file).downcase
          if file_names[file_name]
            conflicts << "File '#{file}' conflicts with '#{file_names[file_name]}'"
          else
            file_names[file_name] = file
          end
        end
      end

      if !conflicts.empty?
        raise "Conflicting file names found: [#{conflicts.join(', ')}]"
      end

      return false
    end

    ##
    # Module method used to configure an input OSW with paths to all OpenStudio::Extension measure and file directories
    ##
    #  @param [Hash] in_osw Initial OSW object as a Hash, keys should be symbolized
    #
    #  @return [Hash]  Output OSW with measure and file paths configured
    def self.configure_osw(in_osw)
      check_for_name_conflicts

      measure_dirs = all_measure_dirs
      file_dirs = all_file_dirs

      in_osw[:measure_paths] = [] if in_osw[:measure_paths].nil?
      in_osw[:file_paths] = [] if in_osw[:file_paths].nil?

      in_osw[:measure_paths] = in_osw[:measure_paths].concat(measure_dirs).uniq
      in_osw[:file_paths] = in_osw[:file_paths].concat(file_dirs).uniq

      return in_osw
    end

    ##
    # Module method used to set the measure argument for measure_dir_name to argument_value,
    # argument_name must appear in the OSW or exception will be raised.  If step_name is nil
    # then all workflow steps matching measure_dir_name will be affected.  If step_name is
    # not nil, then only workflow steps matching measure_dir_name and step_name will be affected.
    ##
    #  @param [Hash] in_osw Initial OSW object as a Hash, keys should be symbolized
    #  @param [String] measure_dir_name Directory name of measure to set argument on
    #  @param [String] argument_name Name of the argument to set
    #  @param [String] argument_value Value to set the argument name to
    #  @param [String] step_name Optional argument, if present used to select workflow step to modify
    #
    #  @return [Hash] Output OSW with measure argument set to argument value
    def self.set_measure_argument(osw, measure_dir_name, argument_name, argument_value, step_name = nil)
      result = false
      osw[:steps].each do |step|
        if step[:measure_dir_name] == measure_dir_name
          if step_name.nil? || step[:name] == step_name
            step[:arguments][argument_name.to_sym] = argument_value
            result = true
          end
        end
      end

      if !result
        if step_name
          raise "Could not set '#{argument_name}' to '#{argument_value}' for measure '#{measure_dir_name}' in step '#{step_name}'"
        else
          raise "Could not set '#{argument_name}' to '#{argument_value}' for measure '#{measure_dir_name}'"
        end
      end

      return osw
    end
  end
end
