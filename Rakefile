########################################################################################################################
#  openstudio(R), Copyright (c) 2008-2022, Alliance for Sustainable Energy, LLC. All rights reserved.
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

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

require 'openstudio/extension/rake_task'
require 'openstudio/extension'
rake_task = OpenStudio::Extension::RakeTask.new
rake_task.set_extension_class(OpenStudio::Extension::Extension, 'nrel/openstudio-extension-gem')

require 'rubocop/rake_task'
RuboCop::RakeTask.new

task default: :spec

desc 'Initialize a new gem'
task :init_new_gem do
  puts 'Initializing a new extension gem'
  print "\n Enter the name of the new gem directory (ex: openstudio-something-gem. Should end with '-gem'): "
  gem_name = $stdin.gets.chomp

  print "\n Enter the path (full or relative to this repo) where you want the new gem directory to be created: "
  dir_path = $stdin.gets.chomp

  # check if directory already exists at path, if so error
  full_dir_name = dir_path + gem_name

  if Dir.exist?(full_dir_name)
    puts "ERROR:  there is already a directory at path #{full_dir_name}... aborting"
  else
    puts "CREATING dir #{full_dir_name}"
    Dir.mkdir full_dir_name
  end

  # copy file structure
  FileUtils.cp('.gitignore', "#{full_dir_name}/.gitignore")
  FileUtils.cp_r(File.join(File.dirname(__FILE__), 'init_templates/template_gemfile.txt'), File.join(full_dir_name, 'Gemfile'))
  FileUtils.cp_r(File.join(File.dirname(__FILE__), 'doc_templates'), full_dir_name)

  Dir.mkdir File.join(full_dir_name, 'lib')
  Dir.mkdir File.join(full_dir_name, 'lib/measures')
  Dir.mkdir File.join(full_dir_name, 'lib/files')

  # Replacement tokens
  gem_name_bare = gem_name.gsub('-gem', '')
  gem_name_underscores_no_os = gem_name_bare.gsub('openstudio-', '').gsub('openstudio', '').tr('-', '_').tr(' ', '_')
  gem_name_spaces = gem_name.split('-').map(&:capitalize).join(' ')
  gem_class_name = gem_name_underscores_no_os.split('_').collect(&:capitalize).join

  # Rewrite the rakefile template
  text = File.read(File.join(File.dirname(__FILE__), 'init_templates/template_rakefile.txt'))
  new_contents = text.gsub(/GEM_CLASS_NAME/, gem_class_name)
  new_contents = new_contents.gsub(/GEM_NAME_UNDERSCORES/, gem_name_underscores_no_os)
  File.open(File.join(full_dir_name, '/Rakefile'), 'w') { |file| file.puts new_contents }

  # Rewrite README with gem-specific tokens and save
  text = File.read(File.join(File.dirname(__FILE__), 'init_templates/README.md'))
  new_contents = text.gsub(/GEM_NAME_SPACES/, gem_name_spaces)
  new_contents = new_contents.gsub(/GEM_NAME_BARE/, gem_name_bare)
  File.open(File.join(full_dir_name, '/README.md'), 'w') { |file| file.puts new_contents }

  # Rewrite gemspec
  text = File.read(File.join(File.dirname(__FILE__), 'init_templates/gemspec.txt'))
  new_contents = text.gsub(/GEM_NAME_UNDERSCORES/, gem_name_underscores_no_os)
  new_contents = new_contents.gsub(/GEM_NAME_BARE/, gem_name_bare)
  new_contents = new_contents.gsub(/GEM_CLASS_NAME/, gem_class_name)
  File.open(File.join(full_dir_name, "#{gem_name_bare}.gemspec"), 'w') { |file| file.puts new_contents }

  # Rewrite spec and spec_helper with gem-specific tokens and save
  Dir.mkdir File.join(full_dir_name, 'spec')
  Dir.mkdir File.join(full_dir_name, 'spec/tests')
  text = File.read(File.join(File.dirname(__FILE__), 'init_templates/spec.rb'))
  new_contents = text.gsub(/GEM_CLASS_NAME/, gem_class_name)
  File.open(File.join(full_dir_name, 'spec', 'tests', "#{gem_name_underscores_no_os}_spec.rb"), 'w') { |file| file.puts new_contents }

  text = File.read(File.join(File.dirname(__FILE__), 'init_templates/spec_helper.rb'))
  new_contents = text.gsub(/GEM_NAME_UNDERSCORES/, gem_name_underscores_no_os)
  File.open(File.join(full_dir_name, 'spec', 'spec_helper.rb'), 'w') { |file| file.puts new_contents }

  # Stub out OpenStudio directory
  Dir.mkdir File.join(full_dir_name, 'lib/openstudio')
  Dir.mkdir File.join(full_dir_name, 'lib/openstudio', gem_name_underscores_no_os)
  text = File.read(File.join(File.dirname(__FILE__), 'init_templates/version.rb'))
  new_contents = text.gsub(/GEM_CLASS_NAME/, gem_class_name)
  File.open(File.join(full_dir_name, 'lib', 'openstudio', gem_name_underscores_no_os, 'version.rb'), 'w') { |file| file.puts new_contents }

  text = File.read(File.join(File.dirname(__FILE__), 'init_templates/openstudio_module.rb'))
  new_contents = text.gsub(/GEM_CLASS_NAME/, gem_class_name)
  new_contents = new_contents.gsub(/GEM_NAME_UNDERSCORES/, gem_name_underscores_no_os)
  File.open(File.join(full_dir_name, 'lib', 'openstudio', "#{gem_name_underscores_no_os}.rb"), 'w') { |file| file.puts new_contents }
end
