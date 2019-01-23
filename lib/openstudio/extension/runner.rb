require 'open3'
require 'openstudio'

module OpenStudio
  module Extension
    class Runner

      def initialize(path)
        # does the actions for the rake task
        puts "Initializing runner with path: #{path}"
        @path = path
      end
      
      # DLM: not sure where this code should go
      def get_run_env()
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
      
      def run_command(command)
        stdout_str, stderr_str, status = Open3.capture3(get_run_env(), command)
        if status.success?
          puts "Command completed successfully"
          puts "stdout: #{stdout_str}"
          puts "stderr: #{stderr_str}"
          return true
        else
          puts "Error running command: '#{command}'"
          puts "stdout: #{stdout_str}"
          puts "stderr: #{stderr_str}"
          return false 
        end
      end

      # test measures of calling gem with OpenStudio CLI system call
      def test_measures_with_cli
        puts "Testing measures with CLI system call"
        measures_dir = @path + '/lib/measures'
        puts "measures path: #{measures_dir}"
        gem_path = `gem environment gempath`
        gem_path = gem_path.split(':')[0]
        gem_path = File.join(gem_path, 'gems')
        puts "GEM PATH: #{gem_path}"

        File.delete('Gemfile.lock') if File.exist?('Gemfile.lock')
        #FileUtils.remove_dir('./test_gems',true) if File.exist?('./test_gems')
        #FileUtils.remove_dir('./bundle', true) if File.exist?('./bundle')


        test_gems_path = @path + '/test_gems'
        system "bundle install --path #{test_gems_path}"
        system 'bundle lock --add_platform ruby'
        
        cli = OpenStudio.getOpenStudioCLI
        puts "CLI: #{cli}"

        the_call = "#{cli} --verbose --bundle Gemfile --bundle_path ./test_gems/ measure -r #{measures_dir}"
        puts "SYSTEM CALL:"
        puts the_call
        STDOUT.flush
        run_command(the_call)
        puts "DONE"
        STDOUT.flush
      end
    end
  end
end