require 'bundler'
require 'open3'
require 'openstudio'
require 'yaml'

module OpenStudio
  module Extension
    class Runner

      # create a Runner capable of calling the OpenStudio CLI with a prebuild bundle
      def initialize(path)
        puts "Initializing runner with path: #{path}"
        @path = File.absolute_path(path)
        @gemfile_path = File.join(@path, 'Gemfile')
        @bundle_install_path = File.join(@path, '.bundle/install/')
        
        raise "#{@path} does not exist" if !File.exists?(@path)
        raise "#{@path} is not a directory" if !File.directory?(@path)
        raise "#{@gemfile_path} does not exist" if !File.exists?(@gemfile_path)
        
        original_dir = Dir.pwd
        begin
          # DLM: this should probably go in some init rake task
          Dir.chdir(@path)
          
          # check existing config
          needs_config = true
          if File.exists?('./.bundle/config')
            puts "config exists"
            config = YAML.load_file('./.bundle/config')
            if config['BUNDLE_PATH'] == @bundle_install_path
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
          Dir.chdir(original_dir)
        end
      end
      
      # DLM: not sure where this code should go
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
      
      def run_command(command, env = {})
        stdout_str, stderr_str, status = Open3.capture3(env, command)
        if status.success?
          #puts "Command completed successfully"
          #puts "stdout: #{stdout_str}"
          #puts "stderr: #{stderr_str}"
          #STDOUT.flush
          return true
        else
          puts "Error running command: '#{command}'"
          puts "stdout: #{stdout_str}"
          puts "stderr: #{stderr_str}"
          STDOUT.flush
          return false 
        end
      end

      # test measures of calling gem with OpenStudio CLI system call
      def test_measures_with_cli
        puts "Testing measures with CLI system call"
        measures_dir = File.join(@path, 'lib/measures/') # DLM: measures_dir should be a method of the extension mixin?
        puts "measures path: #{measures_dir}"

        cli = OpenStudio.getOpenStudioCLI
        puts "CLI: #{cli}"

        the_call = "#{cli} --verbose --bundle #{@gemfile_path} --bundle_path #{@bundle_path} measure -r #{measures_dir}"
        puts "SYSTEM CALL:"
        puts the_call
        STDOUT.flush
        run_command(the_call, get_clean_env())
        puts "DONE"
        STDOUT.flush
      end
    end
  end
end