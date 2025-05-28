# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# if !defined?(Bundler)
  require 'bundler/gem_tasks'
# end
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

# Only load extension tasks if we're not installing
unless ARGV.include?('install')
  require 'openstudio/extension/rake_task'
  require 'openstudio/extension'
  rake_task = OpenStudio::Extension::RakeTask.new
  rake_task.set_extension_class(OpenStudio::Extension::Extension, 'nrel/openstudio-extension-gem')
end

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
