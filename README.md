# OpenStudio::Extension

This gem repository serves as a base for single purpose repositories that host API methods, CLI tools, and OpenStudio measures which leverage those methods and tools.  Other repositories (e.g. urbanopt-geojson-gem) will depend on this repository and inherit/mix-in needed functionality.  The repository is formatted as a gem to allow for semantic versioning via Bundle.  The repository includes methods for testing, documentation, and build tasks.


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'openstudio-extension'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install 'openstudio-extension'

## Usage

To be filled out later. 

# Releasing

* Update change log
* Update version in `/lib/openstudio/extension/version.rb`
* Merge down to master
* Release via github
* run `rake release` from master  