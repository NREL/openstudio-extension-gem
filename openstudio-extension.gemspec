lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'openstudio/extension/version'

Gem::Specification.new do |spec|
  spec.name          = 'openstudio-extension'
  spec.version       = OpenStudio::Extension::VERSION
  spec.authors       = ['Katherine Fleming', 'Nicholas Long', 'Dan Macumber']
  spec.email         = ['katherine.fleming@nrel.gov', 'nicholas.long@nrel.gov', 'daniel.macumber@nrel.gov']
  spec.platform      = Gem::Platform::RUBY

  spec.summary       = 'openstudio base gem for creating generic extensions with encapsulated data and measures.'
  spec.description   = 'openstudio base gem for creating generic extensions with encapsulated data and measures.'
  spec.homepage      = 'https://openstudio.net'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'bundler', '~> 1.9'
  spec.add_development_dependency 'rake', '~> 12.3'
  spec.add_development_dependency 'rspec', '~> 3.7'
  spec.add_development_dependency 'rubocop', '~> 0.54.0'
  spec.add_dependency 'openstudio-workflow'
  spec.add_dependency 'openstudio_measure_tester', '~> 0.1.7'
  spec.add_dependency 'parallel', '~> 1.12.0'
  spec.add_dependency 'json_pure'
end
