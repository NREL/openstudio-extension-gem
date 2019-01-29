require 'bundler'
require 'fileutils'
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
        
        raise "#{@dirname} does not exist" if !File.exists?(@dirname)
        raise "#{@dirname} is not a directory" if !File.directory?(@dirname)
        
        if !File.exists?(@gemfile_path)
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
            check_bundle = run_command('bundle -v', get_clean_env())
            if !check_bundle
              raise "Failed to run command 'bundle -v', check that bundle is installed" if !File.exists?(@dirname)
            end
            
            # TODO: check that ruby version is correct

            # check existing config
            needs_config = true
            if File.exists?('./.bundle/config')
              puts "config exists"
              config = YAML.load_file('./.bundle/config')
              
              if config['BUNDLE_PATH'] == @bundle_install_path || 
                 config['BUNDLE_--PATH'] == @bundle_install_path 
                # already been configured, might not be up to date
                needs_config = false
              end
            end
            
            # check existing platform
            needs_platform = true
            if File.exists?('Gemfile.lock')
              puts "Gemfile.lock exists"
              gemfile_lock = Bundler::LockfileParser.new(Bundler.read_file('Gemfile.lock'))
              if gemfile_lock.platforms.include?('ruby')
                # already been configured, might not be up to date
                needs_platform = false
              end
            end          
            
            puts "needs_config = #{needs_config}"
            if needs_config
              run_command("bundle config --local --path '#{@bundle_install_path}'", get_clean_env())
            end
            
            puts "needs_platform = #{needs_platform}"
            if needs_platform
              run_command('bundle lock --add_platform ruby', get_clean_env())
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
      def get_clean_env()
        # blank out bundler and gem path modifications, will be re-setup by new call
        new_env = {}
        new_env["BUNDLER_ORIG_MANPATH"] = nil
        new_env["BUNDLER_ORIG_PATH"] = nil
        new_env["BUNDLER_VERSION"] = nil
        new_env["BUNDLE_BIN_PATH"] = nil
        new_env["RUBYLIB"] = nil
        new_env["RUBYOPT"] = nil
        
        # DLM: preserve GEM_HOME and GEM_PATH set by current bundle because we are not supporting bundle
        # requires to ruby gems will work, will fail if we require a native gem
        #new_env["GEM_PATH"] = nil
        #new_env["GEM_HOME"] = nil
        
        # DLM: for now, ignore current bundle in case it has binary dependencies in it
        #bundle_gemfile = ENV['BUNDLE_GEMFILE']
        #bundle_path = ENV['BUNDLE_PATH']    
        #if bundle_gemfile.nil? || bundle_path.nil?
          new_env['BUNDLE_GEMFILE'] = nil
          new_env['BUNDLE_PATH'] = nil
        #else
        #  new_env['BUNDLE_GEMFILE'] = bundle_gemfile
        #  new_env['BUNDLE_PATH'] = bundle_path    
        #end  
        
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
          stdout_str, stderr_str, status = Open3.capture3(env, command)
          if status.success?
            #puts "Command completed successfully"
            #puts "stdout: #{stdout_str}"
            #puts "stderr: #{stderr_str}"
            #STDOUT.flush
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
        end
        
        return result
      end

      ##
      # Run the OpenStudio CLI command to test measures on given directory
      # Returns true if the command completes successfully, false otherwise.
      # measures_dir configured in rake_task
      ##
      #  @return [Boolean] 
      def test_measures_with_cli(measures_dir)
        puts "Testing measures with CLI system call"
        puts "measures path: #{measures_dir}"

        cli = OpenStudio.getOpenStudioCLI
        puts "CLI: #{cli}"

        the_call = ''
        if @gemfile_path
          the_call = "#{cli} --verbose --bundle #{@gemfile_path} --bundle_path #{@bundle_path} measure -r #{measures_dir}"
        else
          the_call = "#{cli} --verbose measure -r #{measures_dir}"
        end
        
        puts "SYSTEM CALL:"
        puts the_call
        STDOUT.flush
        result = run_command(the_call, get_clean_env())
        puts "DONE"
        STDOUT.flush
        
        return result
      end

      ##
      # Run the OpenStudio CLI command to update measures on given directory
      # Returns true if the command completes successfully, false otherwise.
      ##
      #  @return [Boolean]
      def update_measures(measures_dir)
        puts "Updating measures with CLI system call"
        puts "measures path: #{measures_dir}"

        cli = OpenStudio.getOpenStudioCLI
        puts "CLI: #{cli}"

        the_call = ''
        if @gemfile_path
          the_call = "#{cli} --verbose --bundle #{@gemfile_path} --bundle_path #{@bundle_path} measure -t #{measures_dir}"
        else
          the_call = "#{cli} --verbose measure -t #{measures_dir}"
        end

        puts "SYSTEM CALL:"
        puts the_call
        STDOUT.flush
        result = run_command(the_call, get_clean_env())
        puts "DONE"
        STDOUT.flush

        return result

      end

      ##
      # List measures in given directory
      # Returns true if the command completes successfully, false otherwise.
      ##
      #  @return [Boolean]

      ##
      def list_measures(measures_dir)
        puts "Listing measures"
        puts "measures path: #{measures_dir}"

        # this is to accommodate a single measures dir (like most gems)
        # or a repo with multiple directories fo measures (like OpenStudio-measures)
        measures = Dir.glob(File.join(measures_dir, '**/measure.rb'))
        if measures.length == 0
          # also try nested 2-deep
          measures = Dir.glob(File.join(measures_dir, '**/**/measure.rb'))
        end
        puts "#{measures.length} MEASURES FOUND"
        measures.each do |measure|
          name = measure.split('/')[-2]
          puts "#{name}"
        end

      end

      # Update measures by copying in the latest resource files from the Extension gem into
      # the measures' respective resources folders.
      # measures_dir configured in rake_task
      # Returns true if the command completes successfully, false otherwise.
      ##
      #  @return [Boolean]
      def copy_measure_resource_files(measures_dir)
        result = false
        puts "Copying updated resource files in /lib/measure_resources directory to individual measures."
        puts "Only files that have actually been changed will be listed."

        # get resource files relative to this file
        resource_path = File.join(File.expand_path(File.dirname(__FILE__)), '../../measure_resources')
        resource_files = Dir.glob(File.join(resource_path, '/*.*'))

        puts "Measure Resources Filepath: #{resource_path}"

        # this is to accommodate a single measures dir (like most gems)
        # or a repo with multiple directories fo measures (like OpenStudio-measures)
        measures = Dir.glob(File.join(measures_dir, '**/resources/*.rb'))
        if measures.length == 0
          # also try nested 2-deep
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
      # measures_dir configured in rake_task
      # Returns true if the command completes successfully, false otherwise.
      ##
      #  @return [Boolean]
      def add_measure_license(measures_dir)
        result = false
        license_file = File.join(File.expand_path(File.dirname(__FILE__)), '../../measure_files/LICENSE.md')
        puts "License file path: #{license_file}"
        measures = Dir["#{measures_dir}/**/measure.rb"]
        measures.each do |measure|
          FileUtils.cp(license_file, "#{File.dirname(measure)}/LICENSE.md")
        end
        result = true
        return result
      end


      # Update measures by adding license file
      # measures_dir configured in rake_task
      # Returns true if the command completes successfully, false otherwise.
      ##
      #  @return [Boolean]
      def add_measure_readme(measures_dir)
        result = false
        readme_file = File.join(File.expand_path(File.dirname(__FILE__)), '../../measure_files/README.md.erb')
        puts "Readme file path: "
        measures = Dir["#{measures_dir}/**/measure.rb"]
        measures.each do |measure|
          next if File.exist?("#{File.dirname(measure)}/README.md.erb")
          next if File.exist?("#{File.dirname(measure)}/README.md")
          puts "adding template README to #{measure}"
          FileUtils.cp(readme_file, "#{File.dirname(measure)}/README.md.erb")
        end
        result = true
        return result
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
          raise "'#{in_osw_path}' does not exist" if !File.exists?(in_osw_path)
          
          in_osw = {}
          File.open(in_osw_path, 'r') do |file|
            in_osw = JSON.parse(file.read, {symbolize_names: true})
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
        puts "CLI: #{cli}"
        
        the_call = ''
        if @gemfile_path
          the_call = "#{cli} --verbose --bundle #{@gemfile_path} --bundle_path #{@bundle_path} run -w #{run_osw_path}"
        else
          the_call = "#{cli} --verbose run -w '#{run_osw_path}'"
        end
        
        puts "SYSTEM CALL:"
        puts the_call
        STDOUT.flush
        result = run_command(the_call, get_clean_env())
        puts "DONE"
        STDOUT.flush
      
        return result
      end
    end
  end
end