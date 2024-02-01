require 'rubygems/dependency_installer.rb'
bundler_version = RUBY_VERSION[0] == "3" ? '~> 2.4.10' : '~> 2.1.0'
dep = Gem::Dependency.new("bundler", bundler_version, :runtime)
puts "Installing bundler '#{bundler_version}' as a runtime dependency"
inst = Gem::DependencyInstaller.new
inst.install dep
