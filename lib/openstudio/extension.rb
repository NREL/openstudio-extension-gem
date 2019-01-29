########################################################################################################################
#  openstudio(R), Copyright (c) 2008-2019, Alliance for Sustainable Energy, LLC. All rights reserved.
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
#  works may not use the "openstudio" trademark, "OS", "os", or any other confusingly similar designation without
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

require 'openstudio/extension/version'
require 'openstudio/extension/runner'

module OpenStudio
  module Extension
    class Extension
      
      # Return the version of the OpenStudio Extension Gem
      def openstudio_extension_version
        OpenStudio::Extension::VERSION
      end

      # Base method
      # Return the absolute path of the measures or nil if there is none, can be used when configuring OSWs
      def measures_dir
        return File.absolute_path(File.join(File.dirname(__FILE__), '../measures/'))
      end

      # Base method
      # List the names (and versions?) of the measures.
      # DLM: do we need this? if we do, what format should it return?  I would prefer to remove this
      def list_measures
        return []
      end

      # Base method
      # Relevant files such as weather data, design days, etc.
      # return the absolute path of the files or nil if there is none, can be used when configuring OSWs
      def files_dir
        return File.absolute_path(File.join(File.dirname(__FILE__), '../files/'))
      end
      
      # Base method
      # return the absolute path of root of this gem
      def root_dir
        return File.absolute_path(File.join(File.dirname(__FILE__), '../../'))
      end
      
      # Base method
      # returns a minimum openstudio version or nil
      # need something like this because cannot restrict os version via gemfile
      # Not sure how to do this yet
      def minimum_openstudio_version
        puts 'return the minimum openstudio version'
        return 'unknown minimum openstudio version'
      end
    end
    
    ##
    # Module method used to configure an input OSW with paths to all OpenStudio::Extension measure and file directories
    ##
    #  @param [Hash] in_osw Initial OSW object as a Hash, keys should be symbolized
    #
    #  @return [Hash]  Output OSW with measure and file paths configured
    def self.configure_osw(in_osw)
      measure_dirs = []
      file_dirs = []
      ObjectSpace.each_object(::Class) do |obj|
        next if !obj.ancestors.include?(OpenStudio::Extension::Extension)

        begin
          measure_dirs << obj.new.measures_dir
        rescue
        end
        
        begin
          file_dirs << obj.new.files_dir
        rescue
        end
        
      end
      
      in_osw[:measure_paths] = in_osw[:measure_paths].concat(measure_dirs).uniq
      in_osw[:file_paths] = in_osw[:file_paths].concat(file_dirs).uniq
      
      return in_osw
    end
  end
end
