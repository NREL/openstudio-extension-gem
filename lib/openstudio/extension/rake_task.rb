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

      def set_extension_class(extension_class, github_repo='')
        @extension_class = extension_class
        @extension = extension_class.new
        @root_dir = @extension.root_dir
        @measures_dir = @extension.measures_dir
        @staged_path = @measures_dir + '/staged'
        @core_dir = @extension.core_dir
        @doc_templates_dir = @extension.doc_templates_dir
        @files_dir = @extension.files_dir
        @github_repo = github_repo
      end

      private

      def setup_subtasks(name)
        namespace name do
          desc 'Run the CLI task to check for measure updates'
          task update_measures: ['measures:add_license', 'measures:add_readme', 'measures:copy_resources', 'update_copyright'] do
            puts 'updating measures'
            runner = OpenStudio::Extension::Runner.new(Dir.pwd)
            runner.update_measures(@measures_dir)
          end

          desc 'List measures'
          task :list_measures do
            puts 'Listing measures'
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

          # namespace for anything runner related
          namespace 'runner' do
            desc 'Initialize a local runner.conf file to set custom runner parameters'
            task :init do
              puts 'Creating runner.conf'
              OpenStudio::Extension::RunnerConfig.init(Dir.pwd)
            end
          end

          desc 'Update copyright on files'
          task :update_copyright do
            # update copyright
            puts 'Updating COPYRIGHT in files'
            runner = OpenStudio::Extension::Runner.new(Dir.pwd)
            runner.update_copyright(@root_dir, @doc_templates_dir)
          end

          desc 'Print the change log from GitHub'
          task :change_log, [:start_date, :end_date, :apikey] do |t, args|
            require 'change_log'
            cl = ChangeLog.new(@github_repo, *args)
            cl.process
            cl.print_issues
          end

          namespace 'bcl' do
            desc 'Test BCL login'
            task :test_login do
              puts 'test BCL login'
              bcl = ::BCL::ComponentMethods.new
              bcl.login
            end

            # for custom search, populate env var: bcl_search_keyword
            desc 'Search BCL'
            task :search_measures do
              puts 'test search BCL'
              bcl = ::BCL::ComponentMethods.new
              bcl.login

              # check for env var specifying keyword first
              if ENV['bcl_search_keyword']
                keyword = ENV['bcl_search_keyword']
              else
                keyword = 'Space'
              end
              num_results = 10
              # bcl.search params: search_string, filter_string, return_all_results?
              puts "searching BCL measures for keyword: #{keyword}"
              results = bcl.search(keyword, "fq[]=bundle:nrel_measure&show_rows=#{num_results}", false)
              puts "there are #{results[:result].count} results"
              results[:result].each do |res|
                puts (res[:measure][:name]).to_s
              end
            end

            # to call with argument: "openstudio:bcl:stage[true]" (true = remove existing staged content)
            desc 'Copy the measures/components to a location that can be uploaded to BCL'
            task :stage, [:reset] do |t, args|
              puts 'Staging measures for BCL'
              # initialize BCL and login
              bcl = ::BCL::ComponentMethods.new
              bcl.login

              # process reset options: true to clear out old staged content
              options = { reset: false }
              if args[:reset].to_s == 'true'
                options[:reset] = true
              end

              # ensure staged dir exists
              FileUtils.mkdir_p(@staged_path)

              # delete existing tarballs if reset is true
              if options[:reset]
                puts 'Deleting existing staged content'
                FileUtils.rm_rf(Dir.glob("#{@staged_path}/*"))
              end

              # create new and existing directories
              FileUtils.mkdir_p(@staged_path.to_s + '/update')
              FileUtils.mkdir_p(@staged_path.to_s + '/push/component')
              FileUtils.mkdir_p(@staged_path.to_s + '/push/measure')

              # keep track of noop, update, push
              noops = 0
              new_ones = 0
              updates = 0

              # get all content directories to process
              dirs = Dir.glob("#{@measures_dir}/*")

              dirs.each do |dir|
                next if dir.include?('Rakefile') || File.basename(dir) == 'staged'
                current_d = Dir.pwd
                content_name = File.basename(dir)
                puts '', '---'
                puts "Generating #{content_name}"

                Dir.chdir(dir)

                # figure out whether to upload new or update existing
                files = Pathname.glob('**/*')
                uuid = nil
                vid = nil
                content_type = 'measure'

                paths = []
                files.each do |file|
                  # don't tar tests/outputs directory
                  next if file.to_s.start_with?('tests/output') # From measure testing process
                  next if file.to_s.start_with?('tests/test') # From openstudio-measure-tester-gem
                  next if file.to_s.start_with?('tests/coverage') # From openstudio-measure-tester-gem
                  next if file.to_s.start_with?('test_results') # From openstudio-measure-tester-gem
                  paths << file.to_s
                  if file.to_s =~ /^.{0,2}component.xml$/ || file.to_s =~ /^.{0,2}measure.xml$/
                    if file.to_s.match?(/^.{0,2}component.xml$/)
                      content_type = 'component'
                    end
                    # extract uuid  and vid
                    uuid, vid = bcl.uuid_vid_from_xml(file)
                  end
                end
                puts "UUID: #{uuid}, VID: #{vid}"

                # note: if uuid is missing, will assume new content
                action = bcl.search_by_uuid(uuid, vid)
                puts "#{content_name} ACTION TO TAKE: #{action}"
                # new content functionality needs to know if measure or component.  update is agnostic.
                if action == 'noop' # ignore up-to-date content
                  puts "  - WARNING: local #{content_name} uuid and vid match BCL... no update will be performed"
                  noops += 1
                  next
                elsif action == 'update'
                  # puts "#{content_name} labeled as update for BCL"
                  destination = @staged_path + '/' + action + '/' + "#{content_name}.tar.gz"
                  updates += 1
                elsif action == 'push'
                  # puts "#{content_name} labeled as new content for BCL"
                  destination = @staged_path + '/' + action + '/' + content_type + "/#{content_name}.tar.gz"
                  new_ones += 1
                end

                puts "destination: #{destination}"

                # copy over only if 'reset_receipts' is set to TRUE. otherwise ignore if file exists already
                if File.exist?(destination)
                  if reset
                    FileUtils.rm(destination)
                    ::BCL.tarball(destination, paths)
                  else
                    puts "*** WARNING: File #{content_name}.tar.gz already exists in staged directory... keeping existing file. To overwrite, set reset_receipts arg to true ***"
                  end
                else
                  ::BCL.tarball(destination, paths)
                end
                Dir.chdir(current_d)
              end
              puts '', "****STAGING DONE**** #{new_ones} new content, #{updates} updates, #{noops} skipped (already up-to-date on BCL)", ''
            end

            desc 'Upload measures from the specified location.'
            task :push do
              puts 'Push measures to BCL'

              # initialize BCL and login
              bcl = ::BCL::ComponentMethods.new
              bcl.login
              reset = false

              total_count = 0
              successes = 0
              errors = 0
              skipped = 0

              # grab all the new measure and component tar files and push to bcl
              ['measure', 'component'].each do |content_type|
                items = []
                paths = Pathname.glob(@staged_path.to_s + "/push/#{content_type}/*.tar.gz")
                paths.each do |path|
                  # puts path
                  items << path.to_s
                end

                items.each do |item|
                  puts item.split('/').last
                  total_count += 1

                  receipt_file = File.dirname(item) + '/' + File.basename(item, '.tar.gz') + '.receipt'
                  if !reset && File.exist?(receipt_file)
                    skipped += 1
                    puts 'SKIP: receipt file found'
                    next
                  end

                  valid, res = bcl.push_content(item, true, "nrel_#{content_type}")
                  if valid
                    successes += 1
                  else
                    errors += 1
                    if res.key?(:error)
                      puts "  ERROR MESSAGE: #{res[:error]}"
                    else
                      puts "ERROR: #{res.inspect.chomp}"
                    end
                  end
                  puts '', '---'
                end
              end

              # grab all the updated content (measures and components) tar files and push to bcl
              items = []
              paths = Pathname.glob(@staged_path.to_s + '/update/*.tar.gz')
            end
          end
        end
      end
    end
  end
end
