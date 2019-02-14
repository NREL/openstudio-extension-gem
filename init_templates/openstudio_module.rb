require 'openstudio/GEM_NAME_UNDERSCORES/version'
require 'openstudio/extension'

module OpenStudio
  module GEM_CLASS_NAME
    class GEM_CLASS_NAME < OpenStudio::Extension::Extension
      # Override parent class
      def initialize
        super

        @root_dir = File.absolute_path(File.join(File.dirname(__FILE__), '..', '..'))
      end
    end
  end
end