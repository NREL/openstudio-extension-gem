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

## TODO

* Add test measure to BuildingSync
* Add test measure to OS-Ext
* run measure tests for each repo
* gather measures 
* push to bcl
* system tests with OSW
    * discover measure paths
    * data paths
    * call OSW with a bundle exec [buildingsync]
    * need to track the path to the CLI
    * have the CLI make its own bundle (OpenStudio)
* 3rd repo that is not a gem. 
    * gemfile, bundle,
    * create osw that doesn't do anything except find buildingsync gem

# Releasing

* Update change log
* Update version in `/lib/openstudio/extension/version.rb`
* Merge down to master
* Release via github
* run `rake release` from master  