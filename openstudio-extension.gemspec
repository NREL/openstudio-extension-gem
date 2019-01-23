lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'openstudio/extension/version'

Gem::Specification.new do |spec|
  spec.name          = 'openstudio-extension'
  spec.version       = OpenStudio::Extension::VERSION
  spec.authors       = ['Nicholas Long', 'Dan Macumber']
  spec.email         = ['nicholas.long@nrel.gov', 'daniel.macumber@nrel.gov']

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

  spec.add_development_dependency 'bundler', '~> 1.14'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '~> 0.63.0'
  spec.add_development_dependency 'rubocop-checkstyle_formatter', '0.4.0'
end