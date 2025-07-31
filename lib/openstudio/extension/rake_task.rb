# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
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
        super
        @name = args.shift || :openstudio

        setup_subtasks(@name)
      end

      def set_extension_class(extension_class, github_repo = '')
        @extension_class = extension_class
        @extension = extension_class.new
        @root_dir = @extension.root_dir
        # Catch if measures_dir is nil, then just make it an empty string
        @measures_dir = @extension.measures_dir || ''
        @staged_path = "#{@measures_dir}/staged"
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

          desc 'Print the change log from GitHub. Date format: yyyy-mm-dd'
          task :change_log, [:start_date, :end_date, :apikey] do |t, args|
            require 'change_log'
            cl = ChangeLog.new(@github_repo, *args)
            cl.process
            cl.print_issues
          end

          namespace 'bcl' do
            # for custom search, populate env var: bcl_search_keyword
            desc 'Search BCL'
            task :search_measures do
              puts 'test search BCL'
              bcl = ::BCL::ComponentMethods.new

              # check for env var specifying keyword first
              keyword = ENV['bcl_search_keyword'] || 'Space'
              num_results = 10
              # bcl.search params: search_string, filter_string, return_all_results?
              puts "searching BCL measures for keyword: #{keyword}"
              results = bcl.search(keyword, "fq[]=bundle:nrel_measure&show_rows=#{num_results}", false)
              puts "there are #{results[:result].count} results"
              results[:result].each do |res|
                puts(res[:measure][:name]).to_s
              end
            end
          end
        end
      end
    end
  end
end
