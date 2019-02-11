require 'bundler'
require 'fileutils'
require 'json'
require 'open3'
require 'openstudio'
require 'yaml'
require 'fileutils'

module OpenStudio
  module Extension
    ##
    # The Runner class provides functionality to run various commands including calls to the OpenStudio CLI.
    #
    class Runner
      ##
      # When initialized with a directory containing a Gemfile, the Runner will attempt to create a bundle
      # compatible with the OpenStudio CLI.
      ##
      #  @param [String] dirname Directory to run commands in, defaults to Dir.pwd. If directory includes a Gemfile then create a local bundle.
      def initialize(dirname = Dir.pwd)
        # DLM: I am not sure if we want to use the main root directory to create these bundles
        # had the idea of passing in a Gemfile name/alias and path to Gemfile, then doing the bundle in ~/OpenStudio/#{alias} or something like that?

        puts "Initializing runner with dirname: '#{dirname}'"
        @dirname = File.absolute_path(dirname)
        @gemfile_path = File.join(@dirname, 'Gemfile')
        @bundle_install_path = File.join(@dirname, '.bundle/install/')
        @original_dir = Dir.pwd

        raise "#{@dirname} does not exist" if !File.exist?(@dirname)
        raise "#{@dirname} is not a directory" if !File.directory?(@dirname)

        if !File.exist?(@gemfile_path)
          # if there is no gemfile set these to nil
          @gemfile_path = nil
          @bundle_install_path = nil
        else
          # there is a gemfile, attempt to create a bundle
          original_dir = Dir.pwd
          begin
            # go to the directory with the gemfile
            Dir.chdir(@dirname)

            # test to see if bundle is installed
            check_bundle = run_command('bundle -v', get_clean_env)
            if !check_bundle
              raise "Failed to run command 'bundle -v', check that bundle is installed" if !File.exist?(@dirname)
            end

            # TODO: check that ruby version is correct

            # check existing config
            needs_config = true
            if File.exist?('./.bundle/config')
              puts 'config exists'
              config = YAML.load_file('./.bundle/config')
             
              if config['BUNDLE_PATH'] == @bundle_install_path 
                # already been configured, might not be up to date
                needs_config = false
              end
            end

            # check existing platform
            needs_platform = true
            if File.exist?('Gemfile.lock')
              puts 'Gemfile.lock exists'
              gemfile_lock = Bundler::LockfileParser.new(Bundler.read_file('Gemfile.lock'))
              if gemfile_lock.platforms.include?('ruby')
                # already been configured, might not be up to date
                needs_platform = false
              end
            end

            puts "needs_config = #{needs_config}"
            if needs_config
              run_command("bundle config --local path '#{@bundle_install_path}'", get_clean_env())
            end

            puts "needs_platform = #{needs_platform}"
            if needs_platform
              run_command('bundle lock --add_platform ruby', get_clean_env())
            end
            
            needs_update = needs_config || needs_platform
            if !needs_update
              if !File.exists?('Gemfile.lock') || File.mtime(@gemfile_path) > File.mtime('Gemfile.lock') 
                needs_update = true
              end
            end
            
            puts "needs_update = #{needs_update}"
            if needs_update
              run_command('bundle update', get_clean_env())
            end
          ensure
            Dir.chdir(@original_dir)
          end
        end
      end

      ##
      # Returns a hash of environment variables that can be merged with the current environment to prevent automatic bundle activation.
      #
      # DLM: should this be a module or class method?
      ##
      #  @return [Hash]
      def get_clean_env
        # blank out bundler and gem path modifications, will be re-setup by new call
        new_env = {}
        new_env['BUNDLER_ORIG_MANPATH'] = nil
        new_env['BUNDLER_ORIG_PATH'] = nil
        new_env['BUNDLER_VERSION'] = nil
        new_env['BUNDLE_BIN_PATH'] = nil
        new_env['RUBYLIB'] = nil
        new_env['RUBYOPT'] = nil

        # DLM: preserve GEM_HOME and GEM_PATH set by current bundle because we are not supporting bundle
        # requires to ruby gems will work, will fail if we require a native gem
        new_env["GEM_PATH"] = nil
        new_env["GEM_HOME"] = nil
        
        # DLM: for now, ignore current bundle in case it has binary dependencies in it
        # bundle_gemfile = ENV['BUNDLE_GEMFILE']
        # bundle_path = ENV['BUNDLE_PATH']
        # if bundle_gemfile.nil? || bundle_path.nil?
        new_env['BUNDLE_GEMFILE'] = nil
        new_env['BUNDLE_PATH'] = nil
        # else
        #  new_env['BUNDLE_GEMFILE'] = bundle_gemfile
        #  new_env['BUNDLE_PATH'] = bundle_path
        # end

        return new_env
      end

      ##
      # Run a command after merging the current environment with env.  Command is run in @dirname, returns to Dir.pwd after completion.
      # Returns true if the command completes successfully, false otherwise.
      # Standard Out, Standard Error, and Status Code are collected and printed, but not returned.
      ##
      #  @return [Boolean]
      def run_command(command, env = {})
        result = false
        original_dir = Dir.pwd
        begin
          Dir.chdir(@dirname)
          
          # DLM: using popen3 here can result in deadlocks
          stdout_str, stderr_str, status = Open3.capture3(env, command)
          if status.success?
            # puts "Command completed successfully"
            # puts "stdout: #{stdout_str}"
            # puts "stderr: #{stderr_str}"
            # STDOUT.flush
            result = true
          else
            puts "Error running command: '#{command}'"
            puts "stdout: #{stdout_str}"
            puts "stderr: #{stderr_str}"
            STDOUT.flush
            result = false
          end
        ensure
          Dir.chdir(original_dir)
          return result
        end

        return result
      end

      ##
      # Get path to all measures found under measure dir.
      ##
      #  @param [String] measures_dir Measures directory
      ##
      #  @return [Array] returns path to all measure directories found under measure dir
      def get_measures_in_dir(measures_dir)
        measures = Dir.glob(File.join(measures_dir, '**/measure.rb'))
        if measures.empty?
          # also try nested 2-deep to support openstudio-measures
          measures = Dir.glob(File.join(measures_dir, '**/**/measure.rb'))
        end

        result = []
        measures.each { |m| result << File.dirname(m) }
        return result
      end

      ##
      # Get path to all measures dirs found under measure dir.
      ##
      #  @param [String] measures_dir Measures directory
      ##
      #  @return [Array] returns path to all directories containing measures found under measure dir
      def get_measure_dirs_in_dir(measures_dir)
        measures = Dir.glob(File.join(measures_dir, '**/measure.rb'))
        if measures.empty?
          # also try nested 2-deep to support openstudio-measures
          measures = Dir.glob(File.join(measures_dir, '**/**/measure.rb'))
        end

        result = []
        measures.each { |m| result << File.dirname(File.dirname(m)) }

        return result.uniq
      end

      ##
      # Run the OpenStudio CLI command to test measures on given directory
      # Returns true if the command completes successfully, false otherwise.
      # measures_dir configured in rake_task
      ##
      #  @return [Boolean]
      def test_measures_with_cli(measures_dir)
        puts 'Testing measures with CLI system call'
        if measures_dir.nil? || measures_dir.empty?
          puts 'Measures dir is nil or empty'
          return false
        end

        puts "measures path: #{measures_dir}"

        cli = OpenStudio.getOpenStudioCLI

        the_call = ''
        if @gemfile_path
          the_call = "#{cli} --verbose --bundle '#{@gemfile_path}' --bundle_path '#{@bundle_install_path}' measure -r '#{measures_dir}'"
        else
          the_call = "#{cli} --verbose measure -r #{measures_dir}"
        end

        puts 'SYSTEM CALL:'
        puts the_call
        STDOUT.flush
        result = run_command(the_call, get_clean_env)
        puts "DONE, result = #{result}"
        STDOUT.flush

        return result
      end

      ##
      # Run the OpenStudio CLI command to update measures on given directory
      # Returns true if the command completes successfully, false otherwise.
      ##
      #  @return [Boolean]
      def update_measures(measures_dir)
        puts 'Updating measures with CLI system call'
        if measures_dir.nil? || measures_dir.empty?
          puts 'Measures dir is nil or empty'
          return false
        end

        result = true
        # DLM: this is a temporary workaround to handle OpenStudio-Measures
        get_measure_dirs_in_dir(measures_dir).each do |measures_dir|
          puts "measures path: #{measures_dir}"

          cli = OpenStudio.getOpenStudioCLI

          the_call = ''
          if @gemfile_path
            the_call = "#{cli} --verbose --bundle '#{@gemfile_path}' --bundle_path '#{@bundle_install_path}' measure -t '#{measures_dir}'"
          else
            the_call = "#{cli} --verbose measure -t '#{measures_dir}'"
          end

          puts 'SYSTEM CALL:'
          puts the_call
          STDOUT.flush
          result &&= run_command(the_call, get_clean_env)
          puts "DONE, result = #{result}"
          STDOUT.flush
        end

        return result
      end

      ##
      # List measures in given directory
      # Returns true if the command completes successfully, false otherwise.
      ##
      #  @return [Boolean]

      ##
      def list_measures(measures_dir)
        puts 'Listing measures'
        if measures_dir.nil? || measures_dir.empty?
          puts 'Measures dir is nil or empty'
          return false
        end

        puts "measures path: #{measures_dir}"

        # this is to accommodate a single measures dir (like most gems)
        # or a repo with multiple directories fo measures (like OpenStudio-measures)
        measures = Dir.glob(File.join(measures_dir, '**/measure.rb'))
        if measures.empty?
          # also try nested 2-deep to support openstudio-measures
          measures = Dir.glob(File.join(measures_dir, '**/**/measure.rb'))
        end
        puts "#{measures.length} MEASURES FOUND"
        measures.each do |measure|
          name = measure.split('/')[-2]
          puts name.to_s
        end
      end

      # Update measures by copying in the latest resource files from the Extension gem into
      # the measures' respective resources folders.
      # measures_dir and all_measure_resource_dirs configured in rake_task
      # Returns true if the command completes successfully, false otherwise.
      ##
      #  @return [Boolean]
      def copy_measure_resource_files(measures_dir, all_measure_resource_dirs)
        puts 'Copying measure resources'
        if measures_dir.nil? || measures_dir.empty?
          puts 'Measures dir is nil or empty'
          return false
        elsif all_measure_resource_dirs.nil? || all_measure_resource_dirs.empty?
          puts 'Measures resources dirs is nil or empty'
          return false
        end

        result = false
        puts 'Copying updated resource files from measure_resources directories to individual measures.'
        puts 'Only files that have actually been changed will be listed.'

        # get all resource files relative to this file
        resource_files = []
        all_measure_resource_dirs.each do |resource_path|
          resource_files.concat(Dir.glob(File.join(resource_path, '/*.*')))
        end

        # this is to accommodate a single measures dir (like most gems)
        # or a repo with multiple directories fo measures (like OpenStudio-measures)
        measures = Dir.glob(File.join(measures_dir, '**/resources/*.rb'))
        if measures.empty?
          # also try nested 2-deep to support openstudio-measures
          measures = Dir.glob(File.join(measures_dir, '**/**/resources/*.rb'))
        end

        # Note: some older measures like AEDG use 'OsLib_SomeName' instead of 'os_lib_some_name'
        # this script isn't replacing those copies

        # loop through resource files
        resource_files.each do |resource_file|
          # loop through measure dirs looking for matching file
          measures.each do |measure_resource|
            next unless File.basename(measure_resource) == File.basename(resource_file)
            next if FileUtils.identical?(resource_file, File.path(measure_resource))
            puts "Replacing #{measure_resource} with #{resource_file}."
            FileUtils.cp(resource_file, File.path(measure_resource))
          end
        end
        result = true

        return result
      end

      # Update measures by adding license file
      # measures_dir and measure_files_dir configured in rake_task
      # Returns true if the command completes successfully, false otherwise.
      ##
      #  @return [Boolean]
      def add_measure_license(measures_dir, measure_files_dir)
        puts 'Adding measure licenses'
        if measures_dir.nil? || measures_dir.empty?
          puts 'Measures dir is nil or empty'
          return false
        elsif measure_files_dir.nil? || measure_files_dir.empty?
          puts 'Measures files dir is nil or empty'
          return false
        end

        result = false
        license_file = File.join(measure_files_dir, 'LICENSE.md')
        puts "License file path: #{license_file}"

        raise "License file not found '#{license_file}'" if !File.exist?(license_file)

        measures = Dir["#{measures_dir}/**/measure.rb"]
        if measures.empty?
          # also try nested 2-deep to support openstudio-measures
          measures = Dir["#{measures_dir}/**/**/measure.rb"]
        end
        measures.each do |measure|
          FileUtils.cp(license_file, "#{File.dirname(measure)}/LICENSE.md")
        end
        result = true
        return result
      end

      # Update measures by adding license file
      # measures_dir and measure_files_dir configured in rake_task
      # Returns true if the command completes successfully, false otherwise.
      ##
      #  @return [Boolean]
      def add_measure_readme(measures_dir, measure_files_dir)
        puts 'Adding measure readmes'
        if measures_dir.nil? || measures_dir.empty?
          puts 'Measures dir is nil or empty'
          return false
        elsif measure_files_dir.nil? || measure_files_dir.empty?
          puts 'Measures files dir is nil or empty'
          return false
        end

        result = false
        readme_file = File.join(measure_files_dir, 'README.md.erb')
        puts "Readme file path: #{readme_file}"

        raise "Readme file not found '#{readme_file}'" if !File.exist?(readme_file)

        measures = Dir["#{measures_dir}/**/measure.rb"]
        if measures.empty?
          # also try nested 2-deep to support openstudio-measures
          measures = Dir["#{measures_dir}/**/**/measure.rb"]
        end
        measures.each do |measure|
          next if File.exist?("#{File.dirname(measure)}/README.md.erb")
          next if File.exist?("#{File.dirname(measure)}/README.md")
          puts "adding template README to #{measure}"
          FileUtils.cp(readme_file, "#{File.dirname(measure)}/README.md.erb")
        end
        result = true
        return result
      end

      def update_measure_copyright(measures_dir, measure_files_dir)
        puts 'Updating measure copyrights'
        if measures_dir.nil? || measures_dir.empty?
          puts 'Measures dir is nil or empty'
          return false
        elsif measure_files_dir.nil? || measure_files_dir.empty?
          puts 'Measures files dir is nil or empty'
          return false
        end

        ruby_regex = /^#.\*{79}.*#.\*{79}$/m
        erb_regex = /^<%.*#.\*{79}.*#.\*{79}.%>$/m
        js_regex = /^\/\* @preserve.*Copyright.*license.{2}\*\//m

        filename = File.join(measure_files_dir, 'copyright_ruby.txt')
        puts "Copyright file path: #{filename}"
        raise "Copyright file not found '#{filename}'" if !File.exist?(filename)
        file = File.open(filename, 'r')
        ruby_header_text = file.read
        file.close
        ruby_header_text.strip!

        filename = File.join(measure_files_dir, 'copyright_erb.txt')
        puts "Copyright file path: #{filename}"
        raise "Copyright file not found '#{filename}'" if !File.exist?(filename)
        file = File.open(filename, 'r')
        erb_header_text = file.read
        file.close
        erb_header_text.strip!

        filename = File.join(measure_files_dir, 'copyright_js.txt')
        puts "Copyright file path: #{filename}"
        raise "Copyright file not found '#{filename}'" if !File.exist?(filename)
        file = File.open(filename, 'r')
        js_header_text = file.read
        file.close
        js_header_text.strip!

        # test if you're in a gem or in the OpenStudio-measures repo
        # OpenStudio-measures can be nested in an extra directory if operating at root of repo vs. within a measures dir
        measures = Dir["#{measures_dir}/**/measure.rb"]
        measures_full_dir = File.join(measures_dir, '**')
        if measures.empty?
          # also try nested 2-deep to support openstudio-measures
          measures = Dir["#{measures_dir}/**/**/measure.rb"]
          if !measures.empty?
            # update measures_full_dir
            measures_full_dir = File.join(measures_dir, '**/**')
          end
        end

        puts "Using measures full dir: #{measures_full_dir}"

        # look for .rb, .html.erb, and .js.erb
        paths = [
          { glob: "#{measures_full_dir}/*.rb", license: ruby_header_text, regex: ruby_regex },
          { glob: "#{measures_full_dir}/*.html.erb", license: erb_header_text, regex: erb_regex },
          { glob: "#{measures_full_dir}/*.js.erb", license: js_header_text, regex: js_regex }
        ]

        paths.each do |path|
          Dir[path[:glob]].each do |file|
            puts "Updating license in file #{file}"
            f = File.read(file)
            if f =~ path[:regex]
              puts '  License found -- updating'
              File.open(file, 'w') { |write| write << f.gsub(path[:regex], path[:license]) }
            elsif f =~ /\(C\)/i || f =~ /\(Copyright\)/i
              puts '  File already has copyright -- skipping'
            else
              puts '  No license found -- adding'
              if f =~ /#!/
                puts '  CANNOT add license to file automatically, add it manually and it will update automatically in the future'
                next
              end
              File.open(file, 'w') { |write| write << f.insert(0, path[:license] + "\n\n") }
            end
          end
        end
      end

      ##
      # Run the OpenStudio CLI on an OSW.  The OSW is configured to include measure and file locations for all loaded OpenStudio Extensions.
      ##
      #  @param [String, Hash] in_osw If string this is the path to an OSW file on disk, if Hash it is loaded JSON with symbolized keys
      #  @param [String] run_dir Directory to run the OSW in, will be created if does not exist
      ##
      #  @return [Boolean] True if command succeeded, false otherwise # DLM: should this return path to out.osw instead?
      def run_osw(in_osw, run_dir)
        run_dir = File.absolute_path(run_dir)

        if in_osw.is_a?(String)
          in_osw_path = in_osw
          raise "'#{in_osw_path}' does not exist" if !File.exist?(in_osw_path)

          in_osw = {}
          File.open(in_osw_path, 'r') do |file|
            in_osw = JSON.parse(file.read, symbolize_names: true)
          end
        end

        osw = OpenStudio::Extension.configure_osw(in_osw)
        osw[:run_directory] = run_dir

        FileUtils.mkdir_p(run_dir)

        run_osw_path = File.join(run_dir, 'in.osw')
        File.open(run_osw_path, 'w') do |file|
          file.puts JSON.pretty_generate(osw)
        end

        cli = OpenStudio.getOpenStudioCLI       
        out_log = run_osw_path + '.log'
        if Gem.win_platform?
          #out_log = "nul"
        else
          #out_log = "/dev/null"
        end
          
        the_call = ''
        if @gemfile_path
          the_call = "#{cli} --verbose --bundle '#{@gemfile_path}' --bundle_path '#{@bundle_install_path}' run -w '#{run_osw_path}' 2>&1 > \"#{out_log}\""
        else
          the_call = "#{cli} --verbose run -w '#{run_osw_path}' 2>&1 > \"#{out_log}\""
        end

        puts 'SYSTEM CALL:'
        puts the_call
        STDOUT.flush
        result = run_command(the_call, get_clean_env)
        puts "DONE, result = #{result}"
        STDOUT.flush

        # DLM: this does not always return false for failed CLI runs, consider checking for failed.job file as backup test

        return result
      end
      
        # run osws, return any failure messages
      def run_osws(osw_files, num_parallel = 1, max_to_run = Float::INFINITY)
        failures = []

        osw_files = osw_files.slice(0, [osw_files.size, max_to_run].min)
 
        Parallel.each(osw_files, in_threads: num_parallel) do |osw|
        #osw_files.each do |osw|
          
          result = run_osw(osw, File.dirname(osw))

          if !result
            failures << "Failed to run OSW '#{osw}'"
          end

        end
        
        return failures
      end      
      
    end
  end
end
