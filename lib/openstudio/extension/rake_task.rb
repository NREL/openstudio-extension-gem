########################################################################################################################
#  OpenStudio(R), Copyright (c) 2008-2019, Alliance for Sustainable Energy, LLC. All rights reserved.
#
#  Redistribution and use in source and binary forms, with or without modification, are permitted provided that the
#  following conditions are met:
#
#  (1) Redistributions of source code must retain the above copyright notice, this list of conditions and the following
#  disclaimer.
#
#  (2) Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the
#  following disclaimer in the documentation and/or other materials provided with the distribution.
#
#  (3) Neither the name of the copyright holder nor the names of any contributors may be used to endorse or promote
#  products derived from this software without specific prior written permission from the respective party.
#
#  (4) Other than as required in clauses (1) and (2), distributions in any form of modifications or other derivative
#  works may not use the "OpenStudio" trademark, "OS", "os", or any other confusingly similar designation without
#  specific prior written permission from Alliance for Sustainable Energy, LLC.
#
#  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
#  INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
#  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER, THE UNITED STATES GOVERNMENT, OR ANY CONTRIBUTORS BE LIABLE FOR
#  ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
#  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
#  AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
#  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
########################################################################################################################

require 'rake'
require 'rake/tasklib'
require 'rake/testtask'
require_relative '../extension'

module OpenStudio
  module Extension
    class RakeTask < Rake::TaskLib
      attr_accessor :name, :measures_dir, :core_dir, :doc_templates_dir, :files_dir

      def initialize(*args, &task_block)
        @name = args.shift || :openstudio

        setup_subtasks(@name)
      end

      def set_extension_class(extension_class)
        @extension_class = extension_class
        @extension = extension_class.new
        @root_dir = @extension.root_dir
        @measures_dir = @extension.measures_dir
        @core_dir = @extension.core_dir
        @doc_templates_dir = @extension.doc_templates_dir
        @files_dir = @extension.files_dir
      end

      private

      def setup_subtasks(name)
        namespace name do
          desc 'Run the CLI task to check for measure updates'
          task update_measures: ['measures:add_license', 'measures:add_readme', 'measures:copy_resources', 'update_copyright'] do
            puts 'updating measures...'
            runner = OpenStudio::Extension::Runner.new(Dir.pwd)
            runner.update_measures(@measures_dir)
          end

          desc 'List measures'
          task :list_measures do
            puts 'Listing measures...'
            runner = OpenStudio::Extension::Runner.new(Dir.pwd)
            runner.list_measures(@measures_dir)
          end

          desc 'Use openstudio system ruby to run tests'
          task :test_with_openstudio do
            # puts Dir.pwd
            # puts Rake.original_dir
            puts 'testing with openstudio'
            runner = OpenStudio::Extension::Runner.new(Dir.pwd)
            result = runner.test_measures_with_cli(@measures_dir)

            if !result
              exit 1
            end
          end

          desc 'Use openstudio docker image to run tests'
          task :test_with_docker do
            puts 'testing with docker'
          end

          # namespace for measure operations
          namespace 'measures' do
            desc 'Copy the resources files to individual measures'
            task :copy_resources do
              # make sure we don't have conflicting resource file names
              OpenStudio::Extension.check_for_name_conflicts

              puts 'Copying resource files from the core library to individual measures'
              runner = OpenStudio::Extension::Runner.new(Dir.pwd)
              runner.copy_core_files(@measures_dir, @core_dir)
            end

            desc 'Add License File to measures'
            task :add_license do
              # copy license file
              puts 'Adding license file to measures'
              runner = OpenStudio::Extension::Runner.new(Dir.pwd)
              runner.add_measure_license(@measures_dir, @doc_templates_dir)
            end

            desc 'Add README.md.erb file if it and README.md do not already exist for a measure'
            task :add_readme do
              # copy README.md.erb file
              puts 'Adding README.md.erb to measures where it and README.md do not exist.'
              puts 'Only files that have actually been changed will be listed.'
              runner = OpenStudio::Extension::Runner.new(Dir.pwd)
              runner.add_measure_readme(@measures_dir, @doc_templates_dir)
            end
          end
        
          desc 'Update copyright on files'
          task :update_copyright do
            # update copyright
            puts 'Updating COPYRIGHT in files'
            runner = OpenStudio::Extension::Runner.new(Dir.pwd)
            runner.update_copyright(@root_dir, @doc_templates_dir)
          end
            
          desc 'Copy the measures to a location that can be uploaded to BCL'
          task :stage_bcl do
            puts 'Staging measures for BCL'
          end

          desc 'Upload measures from the specified location.'
          task :push_bcl do
            puts 'Push measures to BCL'
          end
        end
      end
    end
  end
end
