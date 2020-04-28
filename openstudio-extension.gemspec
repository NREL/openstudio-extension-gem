# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'openstudio/extension/version'

Gem::Specification.new do |spec|
  spec.name          = 'openstudio-extension'
  spec.version       = OpenStudio::Extension::VERSION
  spec.platform      = Gem::Platform::RUBY
  spec.authors       = ['Katherine Fleming', 'Nicholas Long', 'Daniel Macumber']
  spec.email         = ['katherine.fleming@nrel.gov', 'nicholas.long@nrel.gov', 'daniel.macumber@nrel.gov']

  spec.homepage      = 'https://openstudio.net'
  spec.summary       = 'openstudio base gem for creating generic extensions with encapsulated data and measures.'
  spec.description   = 'openstudio base gem for creating generic extensions with encapsulated data and measures.'
  spec.metadata = {
    'bug_tracker_uri' => 'https://github.com/NREL/openstudio-extension-gem/issues',
    'changelog_uri' => 'https://github.com/NREL/openstudio-extension-gem/blob/develop/CHANGELOG.md',
    # 'documentation_uri' =>  'https://www.rubydoc.info/gems/openstudio-extension-gem/#{gem.version}',
    'source_code_uri' => "https://github.com/NREL/openstudio-extension-gem/tree/v#{spec.version}"
  }

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = '~> 2.5.0'

  spec.add_dependency 'bundler', '~> 2.1'
  spec.add_dependency 'openstudio-workflow', '~> 2.0.0'
  spec.add_dependency 'openstudio_measure_tester', '~> 0.2.2'
  spec.add_dependency 'parallel', '~> 1.19.1'

  spec.add_development_dependency 'github_api', '~> 0.18.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.9'

  spec.add_dependency 'bcl', '~> 0.5.9'
end
