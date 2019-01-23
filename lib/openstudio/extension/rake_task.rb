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
      attr_accessor :name

      def initialize(*args, &task_block)
        @name = args.shift || :openstudio

        setup_subtasks(@name)
      end

      private

      def setup_subtasks(name)
        namespace name do
          desc 'Run the CLI task to check for measure updates'
          task :update_measures do
            puts 'updating measures...'
            runner = OpenStudio::Extension::Runner.new
            runner.update_measures
            exit 0
          end

          desc 'Use openstudios system ruby to run tests'
          task :test_with_openstudio do
            #puts Dir.pwd
            #puts Rake.original_dir
            puts 'testing with openstudio'
            runner = OpenStudio::Extension::Runner.new(Dir.pwd)
            runner.test_measures_with_cli

            exit 0
          end

          desc 'Use openstudio docker image to run tests'
          task :test_with_docker do
            puts 'testing with docker'
            exit 0
          end

          desc 'Copy the measures to a location that can be uploaded to BCL'
          task :stage_bcl do
            puts 'Staging measures for BCL'
            exit 0
          end

          desc 'Upload measures from the specified location.'
          task :push_bcl do
            puts 'Push measures to BCL'
            exit 0
          end
        end
      end
    end
  end
end
